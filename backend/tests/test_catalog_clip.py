"""Tests for CLIP embedding in the catalog write path.

Covers:
- ``_embed_catalog_image`` helper: storage shortcut, HTTP fallback, error swallow.
- Endpoint wiring: create, bulk, update.
- Bulk partial-failure isolation.
"""
from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest
from httpx import AsyncClient

# ``app.routers.__init__`` rebinds ``catalog`` to the APIRouter instance,
# shadowing the submodule. Pull the actual module out of sys.modules.
import sys

import app.routers.catalog  # noqa: F401  ensure submodule is loaded

catalog_router = sys.modules["app.routers.catalog"]

# Capture the real helper now — before the autouse stub in conftest replaces
# the module attribute on every test. Unit tests for the helper call this
# captured reference directly to bypass the stub.
_REAL_EMBED_HELPER = catalog_router._embed_catalog_image


async def _signup(
    client: AsyncClient,
    email: str,
    password: str = "supersecret99",
):
    return await client.post("/auth/signup", json={"email": email, "password": password})


# ---------------------------------------------------------------------------
# Unit tests: _embed_catalog_image
# ---------------------------------------------------------------------------


class TestEmbedCatalogImage:
    @pytest.mark.asyncio
    async def test_returns_none_for_empty_url(self):
        assert await _REAL_EMBED_HELPER(None) is None
        assert await _REAL_EMBED_HELPER("") is None

    @pytest.mark.asyncio
    async def test_uses_storage_shortcut_for_catalog_keys(self):
        fake_bytes = b"\x89PNGfake"
        fake_vec = [0.1] * 512

        with patch.object(
            catalog_router, "download_bytes", return_value=fake_bytes
        ) as mock_download, patch.object(
            catalog_router, "embed_image_async", new=AsyncMock(return_value=fake_vec)
        ) as mock_embed:
            url = "https://cdn.example.com/catalog/mango/abc.jpg"
            result = await _REAL_EMBED_HELPER(url)

        assert result == fake_vec
        mock_download.assert_called_once_with("catalog/mango/abc.jpg")
        mock_embed.assert_awaited_once_with(fake_bytes)

    @pytest.mark.asyncio
    async def test_falls_back_to_http_for_non_catalog_urls(self):
        fake_bytes = b"jpegbytes"
        fake_vec = [0.2] * 512

        class _Resp:
            content = fake_bytes
            def raise_for_status(self):
                return None

        class _AsyncCM:
            async def __aenter__(self):
                return self
            async def __aexit__(self, *exc):
                return False
            async def get(self, url):
                return _Resp()

        with patch.object(
            catalog_router.httpx, "AsyncClient", return_value=_AsyncCM()
        ), patch.object(
            catalog_router, "embed_image_async", new=AsyncMock(return_value=fake_vec)
        ) as mock_embed:
            url = "https://other-cdn.example.com/products/foo.jpg"
            result = await _REAL_EMBED_HELPER(url)

        assert result == fake_vec
        mock_embed.assert_awaited_once_with(fake_bytes)

    @pytest.mark.asyncio
    async def test_swallows_fetch_errors_and_returns_none(self):
        with patch.object(
            catalog_router, "download_bytes", side_effect=RuntimeError("S3 down")
        ):
            url = "https://cdn.example.com/catalog/mango/abc.jpg"
            result = await _REAL_EMBED_HELPER(url)

        assert result is None

    @pytest.mark.asyncio
    async def test_swallows_embed_errors_and_returns_none(self):
        with patch.object(
            catalog_router, "download_bytes", return_value=b"bytes"
        ), patch.object(
            catalog_router,
            "embed_image_async",
            new=AsyncMock(side_effect=ValueError("bad image")),
        ):
            url = "https://cdn.example.com/catalog/mango/abc.jpg"
            result = await _REAL_EMBED_HELPER(url)

        assert result is None


# ---------------------------------------------------------------------------
# Endpoint wiring: create / bulk / update
# ---------------------------------------------------------------------------


class TestCatalogEmbeddingWrites:
    @pytest.mark.asyncio
    async def test_create_calls_embed_with_image_front_url(
        self, client: AsyncClient
    ) -> None:
        signup = await _signup(client, "embed-create@outfitter.dev")
        token = signup.json()["access_token"]

        embed_mock = AsyncMock(return_value=None)
        with patch.object(catalog_router, "_embed_catalog_image", embed_mock):
            response = await client.post(
                "/catalog/items",
                headers={"Authorization": f"Bearer {token}"},
                json={
                    "brand": "Mango",
                    "gender": "women",
                    "name": "Linen Shirt",
                    "category": "top",
                    "image_front_url": "https://cdn.example.com/catalog/mango/x.jpg",
                },
            )

        assert response.status_code == 201, response.text
        embed_mock.assert_awaited_once_with("https://cdn.example.com/catalog/mango/x.jpg")

    @pytest.mark.asyncio
    async def test_update_re_embeds_only_when_image_url_changes(
        self, client: AsyncClient
    ) -> None:
        signup = await _signup(client, "embed-update@outfitter.dev")
        token = signup.json()["access_token"]

        create_resp = await client.post(
            "/catalog/items",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "brand": "Mango",
                "gender": "women",
                "name": "Old",
                "category": "top",
                "image_front_url": "https://cdn.example.com/catalog/mango/old.jpg",
            },
        )
        item_id = create_resp.json()["id"]

        # PATCH that does NOT change the image — embed must NOT be called.
        embed_mock_a = AsyncMock(return_value=None)
        with patch.object(catalog_router, "_embed_catalog_image", embed_mock_a):
            no_image_resp = await client.patch(
                f"/catalog/items/{item_id}",
                headers={"Authorization": f"Bearer {token}"},
                json={"name": "Renamed"},
            )
        assert no_image_resp.status_code == 200
        embed_mock_a.assert_not_called()

        # PATCH that DOES change the image — embed must be called once.
        new_url = "https://cdn.example.com/catalog/mango/new.jpg"
        embed_mock_b = AsyncMock(return_value=None)
        with patch.object(catalog_router, "_embed_catalog_image", embed_mock_b):
            image_resp = await client.patch(
                f"/catalog/items/{item_id}",
                headers={"Authorization": f"Bearer {token}"},
                json={"image_front_url": new_url},
            )
        assert image_resp.status_code == 200
        embed_mock_b.assert_awaited_once_with(new_url)

    @pytest.mark.asyncio
    async def test_bulk_create_invokes_embed_per_item(
        self, client: AsyncClient
    ) -> None:
        signup = await _signup(client, "embed-bulk@outfitter.dev")
        token = signup.json()["access_token"]

        embed_mock = AsyncMock(return_value=None)
        with patch.object(catalog_router, "_embed_catalog_image", embed_mock):
            response = await client.post(
                "/catalog/items/bulk",
                headers={"Authorization": f"Bearer {token}"},
                json=[
                    {
                        "brand": "Mango",
                        "gender": "women",
                        "name": "A",
                        "category": "top",
                        "image_front_url": "https://cdn.example.com/catalog/mango/a.jpg",
                    },
                    {
                        "brand": "Mango",
                        "gender": "women",
                        "name": "B",
                        "category": "top",
                        "image_front_url": "https://cdn.example.com/catalog/mango/b.jpg",
                    },
                ],
            )

        assert response.status_code == 200, response.text
        body = response.json()
        assert body["created"] == 2
        assert body["failed"] == 0
        assert embed_mock.await_count == 2
        called_urls = {call.args[0] for call in embed_mock.call_args_list}
        assert called_urls == {
            "https://cdn.example.com/catalog/mango/a.jpg",
            "https://cdn.example.com/catalog/mango/b.jpg",
        }

    @pytest.mark.asyncio
    async def test_bulk_create_isolates_embedding_failure_per_item(
        self, client: AsyncClient
    ) -> None:
        """A single embed failure must not roll back successful siblings.

        ``_embed_catalog_image`` itself swallows errors, so the bulk loop
        observes ``None`` not an exception — each item is created with
        ``clip_embedding=None`` and the bulk response shows zero failures.
        """
        signup = await _signup(client, "embed-bulk-isolated@outfitter.dev")
        token = signup.json()["access_token"]

        async def _maybe_embed(url):
            if "fail" in url:
                return None  # mirrors helper behaviour: error swallowed → None
            return None

        with patch.object(catalog_router, "_embed_catalog_image", side_effect=_maybe_embed):
            response = await client.post(
                "/catalog/items/bulk",
                headers={"Authorization": f"Bearer {token}"},
                json=[
                    {
                        "brand": "Mango",
                        "gender": "women",
                        "name": "OK",
                        "category": "top",
                        "image_front_url": "https://cdn.example.com/catalog/mango/ok.jpg",
                    },
                    {
                        "brand": "Mango",
                        "gender": "women",
                        "name": "Fail",
                        "category": "top",
                        "image_front_url": "https://cdn.example.com/catalog/mango/fail.jpg",
                    },
                ],
            )

        assert response.status_code == 200, response.text
        body = response.json()
        assert body["created"] == 2
        assert body["failed"] == 0
