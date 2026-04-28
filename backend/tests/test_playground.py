import base64
import uuid
from unittest.mock import AsyncMock

import pytest
from httpx import AsyncClient

from app.models.catalog import CatalogItem


async def _signup(client: AsyncClient, email: str = "playground@outfitter.dev"):
    return await client.post("/auth/signup", json={"email": email, "password": "supersecret99"})


async def _seed_item(db, **overrides) -> CatalogItem:
    defaults = dict(
        brand="Mango",
        gender="women",
        category="top",
        name="Test Tee",
        color=["black"],
        style_tags=["casual"],
        image_front_url="https://cdn.example.com/test-tee.jpg",
    )
    defaults.update(overrides)
    item = CatalogItem(**defaults)
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item


@pytest.mark.asyncio
async def test_playground_generate_happy_path(client: AsyncClient, db, monkeypatch):
    signup_resp = await _signup(client)
    token = signup_resp.json()["access_token"]
    item = await _seed_item(db)

    fake_b64 = base64.b64encode(b"generated").decode()
    fake_service = AsyncMock(return_value=[f"data:image/png;base64,{fake_b64}"])
    monkeypatch.setattr(
        "app.routers.playground.generate_outfit_image",
        fake_service,
    )

    response = await client.post(
        "/playground/generate-image",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "catalog_item_ids": [str(item.id)],
            "prompt": "render this on a model",
            "size": "1024x1536",
            "quality": "high",
            "n": 1,
        },
    )

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["images"] == [f"data:image/png;base64,{fake_b64}"]
    assert body["model"] == "gpt-image-2"
    assert body["item_count"] == 1
    assert isinstance(body["elapsed_ms"], int)

    fake_service.assert_awaited_once()
    args, kwargs = fake_service.await_args
    assert kwargs["reference_urls"] == ["https://cdn.example.com/test-tee.jpg"]
    assert kwargs["prompt"] == "render this on a model"
    assert kwargs["size"] == "1024x1536"
    assert kwargs["quality"] == "high"
    assert kwargs["n"] == 1


@pytest.mark.asyncio
async def test_playground_unauthorized(client: AsyncClient):
    response = await client.post(
        "/playground/generate-image",
        json={
            "catalog_item_ids": [str(uuid.uuid4())],
            "prompt": "x",
        },
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_playground_unknown_item_id(client: AsyncClient, db):
    signup_resp = await _signup(client, email="unknown@outfitter.dev")
    token = signup_resp.json()["access_token"]
    bogus = uuid.uuid4()

    response = await client.post(
        "/playground/generate-image",
        headers={"Authorization": f"Bearer {token}"},
        json={"catalog_item_ids": [str(bogus)], "prompt": "x"},
    )
    assert response.status_code == 404
    assert str(bogus) in response.json()["detail"]


@pytest.mark.asyncio
async def test_playground_validation_empty_prompt(client: AsyncClient, db):
    signup_resp = await _signup(client, email="empty@outfitter.dev")
    token = signup_resp.json()["access_token"]
    item = await _seed_item(db)

    response = await client.post(
        "/playground/generate-image",
        headers={"Authorization": f"Bearer {token}"},
        json={"catalog_item_ids": [str(item.id)], "prompt": ""},
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_playground_validation_no_items(client: AsyncClient, db):
    signup_resp = await _signup(client, email="noitems@outfitter.dev")
    token = signup_resp.json()["access_token"]

    response = await client.post(
        "/playground/generate-image",
        headers={"Authorization": f"Bearer {token}"},
        json={"catalog_item_ids": [], "prompt": "x"},
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_playground_validation_too_many_items(client: AsyncClient, db):
    signup_resp = await _signup(client, email="toomany@outfitter.dev")
    token = signup_resp.json()["access_token"]

    response = await client.post(
        "/playground/generate-image",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "catalog_item_ids": [str(uuid.uuid4()) for _ in range(17)],
            "prompt": "x",
        },
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_playground_proxy_error_maps_to_502(client: AsyncClient, db, monkeypatch):
    from app.services.codex_image_service import CodexProxyError

    signup_resp = await _signup(client, email="proxyerr@outfitter.dev")
    token = signup_resp.json()["access_token"]
    item = await _seed_item(db)

    async def boom(**_kwargs):
        raise CodexProxyError("500: upstream blew up")

    monkeypatch.setattr("app.routers.playground.generate_outfit_image", boom)

    response = await client.post(
        "/playground/generate-image",
        headers={"Authorization": f"Bearer {token}"},
        json={"catalog_item_ids": [str(item.id)], "prompt": "x"},
    )
    assert response.status_code == 502
    assert "Image generation failed" in response.json()["detail"]


@pytest.mark.asyncio
async def test_playground_timeout_maps_to_504(client: AsyncClient, db, monkeypatch):
    from app.services.codex_image_service import CodexProxyTimeout

    signup_resp = await _signup(client, email="timeout@outfitter.dev")
    token = signup_resp.json()["access_token"]
    item = await _seed_item(db)

    async def slow(**_kwargs):
        raise CodexProxyTimeout("read timeout")

    monkeypatch.setattr("app.routers.playground.generate_outfit_image", slow)

    response = await client.post(
        "/playground/generate-image",
        headers={"Authorization": f"Bearer {token}"},
        json={"catalog_item_ids": [str(item.id)], "prompt": "x"},
    )
    assert response.status_code == 504
    assert response.json()["detail"] == "Image generation timed out"
