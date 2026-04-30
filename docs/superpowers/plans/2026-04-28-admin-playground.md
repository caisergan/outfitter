# Admin Playground (gpt-image-2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `/playground` page to the admin panel that lets the operator pick catalog items, type a free-form prompt, and generate images via the local OpenAI-compatible proxy (`http://localhost:8317/v1`) using `gpt-image-2`.

**Architecture:** New FastAPI router (`/playground/generate-image`) calls a thin httpx-based service that downloads each selected catalog item's `image_front_url` and forwards it as `multipart/form-data` to the proxy's `/images/edits` endpoint. Returns base64 data URLs to the admin UI. No DB writes; admin-only; auth via existing JWT middleware.

**Tech Stack:** FastAPI, SQLAlchemy async, httpx (already a dep), pytest + pytest-asyncio + pytest-httpx; Next.js 15 (admin), shadcn/ui components, Tailwind, sonner toasts, lucide-react icons.

**Spec:** `docs/superpowers/specs/2026-04-28-admin-playground-design.md`

---

## File Structure

**Backend — create:**
- `backend/app/schemas/playground.py` — request/response Pydantic models
- `backend/app/services/codex_image_service.py` — proxy client + typed errors
- `backend/app/routers/playground.py` — single endpoint `POST /playground/generate-image`
- `backend/tests/test_playground.py` — pytest module

**Backend — modify:**
- `backend/app/config.py` — add `CODEX_PROXY_URL`, `CODEX_PROXY_API_KEY`
- `backend/app/main.py` — register router

**Frontend — create:**
- `admin/src/app/playground/page.js` — single client component

**Frontend — modify:**
- `admin/src/lib/api.js` — add `generatePlaygroundImage(payload)`
- `admin/src/components/Sidebar.js` — add Playground nav entry

---

## Task 1: Pydantic schemas

**Files:**
- Create: `backend/app/schemas/playground.py`

- [ ] **Step 1: Write the schemas file**

```python
# backend/app/schemas/playground.py
import uuid
from typing import Annotated, Literal

from pydantic import BaseModel, Field

PlaygroundSize = Literal["1024x1024", "1024x1536", "1536x1024"]
PlaygroundQuality = Literal["low", "medium", "high"]


class PlaygroundGenerateRequest(BaseModel):
    catalog_item_ids: Annotated[list[uuid.UUID], Field(min_length=1, max_length=16)]
    prompt: Annotated[str, Field(min_length=1, max_length=2000)]
    size: PlaygroundSize = "1024x1536"
    quality: PlaygroundQuality = "high"
    n: Annotated[int, Field(ge=1, le=4)] = 1


class PlaygroundGenerateResponse(BaseModel):
    images: list[str]   # data URLs ("data:image/png;base64,...")
    model: str
    item_count: int
    elapsed_ms: int
```

- [ ] **Step 2: Verify the module imports clean**

Run: `cd backend && python -c "from app.schemas.playground import PlaygroundGenerateRequest, PlaygroundGenerateResponse; print('ok')"`
Expected: `ok`

- [ ] **Step 3: Commit**

```bash
git add backend/app/schemas/playground.py
git commit -m "feat(playground): add request/response schemas for image generation"
```

---

## Task 2: Add proxy settings

**Files:**
- Modify: `backend/app/config.py`

- [ ] **Step 1: Add settings fields**

In `backend/app/config.py`, inside the `Settings` class, add directly after the `KLING_API_KEY` line in the "AI APIs" block:

```python
    # OpenAI-compatible proxy for gpt-image-2 (admin playground)
    CODEX_PROXY_URL: str = "http://localhost:8317/v1"
    CODEX_PROXY_API_KEY: str = "dummy"
```

- [ ] **Step 2: Verify settings load**

Run: `cd backend && python -c "from app.config import settings; print(settings.CODEX_PROXY_URL, settings.CODEX_PROXY_API_KEY)"`
Expected: `http://localhost:8317/v1 dummy`

- [ ] **Step 3: Commit**

```bash
git add backend/app/config.py
git commit -m "feat(config): add CODEX_PROXY_URL and CODEX_PROXY_API_KEY settings"
```

---

## Task 3: Codex image service — happy path (TDD)

**Files:**
- Create: `backend/app/services/codex_image_service.py`
- Create: `backend/tests/test_codex_image_service.py`

- [ ] **Step 1: Write the failing happy-path test**

```python
# backend/tests/test_codex_image_service.py
import base64

import httpx
import pytest

from app.services import codex_image_service


@pytest.mark.asyncio
async def test_generate_outfit_image_happy_path(httpx_mock):
    # Mock the two reference image GETs and the proxy POST.
    httpx_mock.add_response(
        url="https://cdn.example.com/a.jpg",
        method="GET",
        content=b"\x89PNG\r\n\x1a\nfake-a",
    )
    httpx_mock.add_response(
        url="https://cdn.example.com/b.jpg",
        method="GET",
        content=b"\x89PNG\r\n\x1a\nfake-b",
    )
    payload_b64 = base64.b64encode(b"generated-image-bytes").decode()
    httpx_mock.add_response(
        url="http://localhost:8317/v1/images/edits",
        method="POST",
        json={"data": [{"b64_json": payload_b64}]},
    )

    images = await codex_image_service.generate_outfit_image(
        reference_urls=["https://cdn.example.com/a.jpg", "https://cdn.example.com/b.jpg"],
        prompt="render these on a runway model",
        size="1024x1536",
        quality="high",
        n=1,
    )

    assert images == [f"data:image/png;base64,{payload_b64}"]

    # Confirm the proxy request shape: model, multiple image parts, prompt, size, quality, n.
    proxy_req = next(
        r for r in httpx_mock.get_requests()
        if r.url == httpx.URL("http://localhost:8317/v1/images/edits")
    )
    body = proxy_req.content.decode("latin-1")
    assert proxy_req.headers["authorization"] == "Bearer dummy"
    assert 'name="model"' in body and "gpt-image-2" in body
    assert body.count('name="image[]"') == 2
    assert 'name="prompt"' in body and "render these on a runway model" in body
    assert 'name="size"' in body and "1024x1536" in body
    assert 'name="quality"' in body and "high" in body
    assert 'name="n"' in body
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd backend && pytest tests/test_codex_image_service.py::test_generate_outfit_image_happy_path -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'app.services.codex_image_service'`

- [ ] **Step 3: Implement the service (happy path only)**

```python
# backend/app/services/codex_image_service.py
import asyncio
import logging

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

_DOWNLOAD_TIMEOUT = httpx.Timeout(10.0)
_PROXY_TIMEOUT = httpx.Timeout(90.0, connect=10.0)


class CodexProxyError(RuntimeError):
    """Proxy returned a non-2xx response."""


class CodexProxyTimeout(RuntimeError):
    """Proxy did not respond within the timeout."""


class ReferenceImageError(RuntimeError):
    """Failed to fetch a reference image (S3/CDN)."""


async def _download(url: str, client: httpx.AsyncClient) -> bytes:
    response = await client.get(url, timeout=_DOWNLOAD_TIMEOUT)
    response.raise_for_status()
    return response.content


async def generate_outfit_image(
    reference_urls: list[str],
    prompt: str,
    size: str,
    quality: str,
    n: int,
) -> list[str]:
    """Send reference images + prompt to the proxy's /images/edits endpoint.

    Returns a list of ``data:image/png;base64,...`` strings.
    """
    async with httpx.AsyncClient() as client:
        image_bytes = await asyncio.gather(
            *(_download(url, client) for url in reference_urls)
        )

        files = [("image[]", (f"ref-{i}.png", b, "image/png")) for i, b in enumerate(image_bytes)]
        data = {
            "model": "gpt-image-2",
            "prompt": prompt,
            "size": size,
            "quality": quality,
            "n": str(n),
        }

        response = await client.post(
            f"{settings.CODEX_PROXY_URL}/images/edits",
            headers={"Authorization": f"Bearer {settings.CODEX_PROXY_API_KEY}"},
            files=files,
            data=data,
            timeout=_PROXY_TIMEOUT,
        )
        response.raise_for_status()
        body = response.json()

    return [f"data:image/png;base64,{item['b64_json']}" for item in body.get("data", [])]
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd backend && pytest tests/test_codex_image_service.py::test_generate_outfit_image_happy_path -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/codex_image_service.py backend/tests/test_codex_image_service.py
git commit -m "feat(playground): codex image service happy path"
```

---

## Task 4: Codex image service — error paths (TDD)

**Files:**
- Modify: `backend/app/services/codex_image_service.py`
- Modify: `backend/tests/test_codex_image_service.py`

- [ ] **Step 1: Write the failing error-path tests**

Append to `backend/tests/test_codex_image_service.py`:

```python
@pytest.mark.asyncio
async def test_generate_outfit_image_reference_download_fails(httpx_mock):
    httpx_mock.add_response(
        url="https://cdn.example.com/missing.jpg",
        method="GET",
        status_code=404,
    )

    with pytest.raises(codex_image_service.ReferenceImageError):
        await codex_image_service.generate_outfit_image(
            reference_urls=["https://cdn.example.com/missing.jpg"],
            prompt="x",
            size="1024x1024",
            quality="high",
            n=1,
        )


@pytest.mark.asyncio
async def test_generate_outfit_image_proxy_returns_500(httpx_mock):
    httpx_mock.add_response(
        url="https://cdn.example.com/a.jpg",
        method="GET",
        content=b"fake",
    )
    httpx_mock.add_response(
        url="http://localhost:8317/v1/images/edits",
        method="POST",
        status_code=500,
        json={"error": {"message": "boom"}},
    )

    with pytest.raises(codex_image_service.CodexProxyError):
        await codex_image_service.generate_outfit_image(
            reference_urls=["https://cdn.example.com/a.jpg"],
            prompt="x",
            size="1024x1024",
            quality="high",
            n=1,
        )


@pytest.mark.asyncio
async def test_generate_outfit_image_proxy_timeout(httpx_mock):
    httpx_mock.add_response(
        url="https://cdn.example.com/a.jpg",
        method="GET",
        content=b"fake",
    )
    httpx_mock.add_exception(
        httpx.ReadTimeout("timed out"),
        url="http://localhost:8317/v1/images/edits",
        method="POST",
    )

    with pytest.raises(codex_image_service.CodexProxyTimeout):
        await codex_image_service.generate_outfit_image(
            reference_urls=["https://cdn.example.com/a.jpg"],
            prompt="x",
            size="1024x1024",
            quality="high",
            n=1,
        )
```

- [ ] **Step 2: Run the new tests to verify they fail**

Run: `cd backend && pytest tests/test_codex_image_service.py -v`
Expected: the 3 new tests FAIL — the service raises `httpx.HTTPStatusError` / `httpx.ReadTimeout` instead of the typed errors.

- [ ] **Step 3: Wrap network calls in typed errors**

Replace the body of `generate_outfit_image` in `backend/app/services/codex_image_service.py` with:

```python
async def generate_outfit_image(
    reference_urls: list[str],
    prompt: str,
    size: str,
    quality: str,
    n: int,
) -> list[str]:
    async with httpx.AsyncClient() as client:
        try:
            image_bytes = await asyncio.gather(
                *(_download(url, client) for url in reference_urls)
            )
        except httpx.HTTPError as exc:
            logger.exception("Reference image download failed")
            raise ReferenceImageError(str(exc)) from exc

        files = [("image[]", (f"ref-{i}.png", b, "image/png")) for i, b in enumerate(image_bytes)]
        data = {
            "model": "gpt-image-2",
            "prompt": prompt,
            "size": size,
            "quality": quality,
            "n": str(n),
        }

        try:
            response = await client.post(
                f"{settings.CODEX_PROXY_URL}/images/edits",
                headers={"Authorization": f"Bearer {settings.CODEX_PROXY_API_KEY}"},
                files=files,
                data=data,
                timeout=_PROXY_TIMEOUT,
            )
            response.raise_for_status()
        except (httpx.TimeoutException, httpx.ReadTimeout) as exc:
            raise CodexProxyTimeout(str(exc)) from exc
        except httpx.HTTPStatusError as exc:
            detail = exc.response.text[:500] if exc.response is not None else str(exc)
            raise CodexProxyError(f"{exc.response.status_code}: {detail}") from exc
        except httpx.HTTPError as exc:
            raise CodexProxyError(str(exc)) from exc

        body = response.json()

    return [f"data:image/png;base64,{item['b64_json']}" for item in body.get("data", [])]
```

- [ ] **Step 4: Run all service tests**

Run: `cd backend && pytest tests/test_codex_image_service.py -v`
Expected: all 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/codex_image_service.py backend/tests/test_codex_image_service.py
git commit -m "feat(playground): typed errors for codex service (download/proxy/timeout)"
```

---

## Task 5: Router — happy path (TDD)

**Files:**
- Create: `backend/app/routers/playground.py`
- Modify: `backend/app/main.py`
- Create: `backend/tests/test_playground.py`

- [ ] **Step 1: Write the failing happy-path test**

```python
# backend/tests/test_playground.py
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd backend && pytest tests/test_playground.py::test_playground_generate_happy_path -v`
Expected: FAIL with 404 (route not registered) or import error.

- [ ] **Step 3: Implement the router**

```python
# backend/app/routers/playground.py
import logging
import time
import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.jwt import get_current_user
from app.database import get_db
from app.models.catalog import CatalogItem
from app.models.user import User
from app.schemas.playground import (
    PlaygroundGenerateRequest,
    PlaygroundGenerateResponse,
)
from app.services.codex_image_service import (
    CodexProxyError,
    CodexProxyTimeout,
    ReferenceImageError,
    generate_outfit_image,
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/playground", tags=["playground"])

DbDep = Annotated[AsyncSession, Depends(get_db)]
CurrentUserDep = Annotated[User, Depends(get_current_user)]


@router.post("/generate-image", response_model=PlaygroundGenerateResponse)
async def generate_image(
    body: PlaygroundGenerateRequest,
    db: DbDep,
    _: CurrentUserDep,
) -> PlaygroundGenerateResponse:
    ids: list[uuid.UUID] = list(body.catalog_item_ids)

    result = await db.execute(select(CatalogItem).where(CatalogItem.id.in_(ids)))
    items = result.scalars().all()
    found = {item.id: item for item in items}

    missing = [i for i in ids if i not in found]
    if missing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Catalog item {missing[0]} not found",
        )

    reference_urls = [found[i].image_front_url for i in ids]

    started = time.perf_counter()
    try:
        images = await generate_outfit_image(
            reference_urls=reference_urls,
            prompt=body.prompt,
            size=body.size,
            quality=body.quality,
            n=body.n,
        )
    except CodexProxyTimeout as exc:
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail="Image generation timed out",
        ) from exc
    except CodexProxyError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Image generation failed: {exc}",
        ) from exc
    except ReferenceImageError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Failed to fetch reference image: {exc}",
        ) from exc

    elapsed_ms = int((time.perf_counter() - started) * 1000)

    return PlaygroundGenerateResponse(
        images=images,
        model="gpt-image-2",
        item_count=len(ids),
        elapsed_ms=elapsed_ms,
    )
```

- [ ] **Step 4: Register the router**

In `backend/app/main.py`:

Find the line:

```python
from app.routers import auth, catalog, wardrobe, outfits, tryon, storage
```

Replace with:

```python
from app.routers import auth, catalog, wardrobe, outfits, tryon, storage, playground
```

Find the block:

```python
app.include_router(tryon)
app.include_router(storage)
```

Replace with:

```python
app.include_router(tryon)
app.include_router(storage)
app.include_router(playground)
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd backend && pytest tests/test_playground.py::test_playground_generate_happy_path -v`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add backend/app/routers/playground.py backend/app/main.py backend/tests/test_playground.py
git commit -m "feat(playground): POST /playground/generate-image happy path"
```

---

## Task 6: Router — error paths (TDD)

**Files:**
- Modify: `backend/tests/test_playground.py`

- [ ] **Step 1: Write the failing error-path tests**

Append to `backend/tests/test_playground.py`:

```python
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
```

- [ ] **Step 2: Run the new tests**

Run: `cd backend && pytest tests/test_playground.py -v`
Expected: all 7 tests PASS (the router from Task 5 already implements these branches).

- [ ] **Step 3: Run the full backend suite for regressions**

Run: `cd backend && pytest -q`
Expected: all tests PASS (no regressions in catalog/wardrobe/auth/storage suites).

- [ ] **Step 4: Commit**

```bash
git add backend/tests/test_playground.py
git commit -m "test(playground): cover 401/404/422/502/504 error paths"
```

---

## Task 7: Frontend api helper

**Files:**
- Modify: `admin/src/lib/api.js`

- [ ] **Step 1: Append a new section to `admin/src/lib/api.js`**

Add at the bottom of the file:

```javascript
// ── Playground ───────────────────────────────────────────────────────────────

export async function generatePlaygroundImage(payload) {
  // payload: { catalog_item_ids: string[], prompt: string,
  //            size?: string, quality?: string, n?: number }
  return apiFetch("/playground/generate-image", { method: "POST", body: payload });
}
```

- [ ] **Step 2: Verify the file still parses**

Run: `cd admin && node -e "require('./src/lib/api.js')" 2>&1 | head -5`
Expected: no parse errors. (Next will catch any anyway on dev start.)

- [ ] **Step 3: Commit**

```bash
git add admin/src/lib/api.js
git commit -m "feat(admin): generatePlaygroundImage api helper"
```

---

## Task 8: Sidebar entry

**Files:**
- Modify: `admin/src/components/Sidebar.js`

- [ ] **Step 1: Add the Playground nav entry**

In `admin/src/components/Sidebar.js`:

Find:

```javascript
import {
    LayoutDashboard,
    Search,
    Shirt,
    Layers,
    Camera,
} from "lucide-react";
```

Replace with:

```javascript
import {
    LayoutDashboard,
    Search,
    Shirt,
    Layers,
    Camera,
    Sparkles,
} from "lucide-react";
```

Find:

```javascript
const navItems = [
    { href: "/", label: "Dashboard", icon: LayoutDashboard },
    { href: "/catalog", label: "Catalog", icon: Search },
    { href: "/wardrobe", label: "Wardrobe", icon: Shirt },
    { href: "/outfits", label: "Outfits", icon: Layers },
    { href: "/tryon", label: "Try-On", icon: Camera },
];
```

Replace with:

```javascript
const navItems = [
    { href: "/", label: "Dashboard", icon: LayoutDashboard },
    { href: "/catalog", label: "Catalog", icon: Search },
    { href: "/wardrobe", label: "Wardrobe", icon: Shirt },
    { href: "/outfits", label: "Outfits", icon: Layers },
    { href: "/tryon", label: "Try-On", icon: Camera },
    { href: "/playground", label: "Playground", icon: Sparkles },
];
```

- [ ] **Step 2: Commit**

```bash
git add admin/src/components/Sidebar.js
git commit -m "feat(admin): add Playground entry to sidebar"
```

---

## Task 9: Playground page

**Files:**
- Create: `admin/src/app/playground/page.js`

- [ ] **Step 1: Create the directory and file**

Run: `mkdir -p admin/src/app/playground`

- [ ] **Step 2: Write the page component**

Create `admin/src/app/playground/page.js` with this full content:

```javascript
"use client";

import { useEffect, useState } from "react";
import {
    searchCatalog,
    getCatalogFilterOptions,
    generatePlaygroundImage,
} from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Textarea } from "@/components/ui/textarea";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Skeleton } from "@/components/ui/skeleton";
import {
    Sparkles,
    Search,
    Loader2,
    AlertCircle,
    ChevronLeft,
    ChevronRight,
    ChevronDown,
    ChevronUp,
    Check,
    X,
    Download,
    Image as ImageIcon,
} from "lucide-react";
import { toast } from "sonner";

const LIMIT = 20;
const MAX_SELECTED = 16;

const FILTER_FIELDS = [
    { key: "category", label: "Category", optionsKey: "categories" },
    { key: "brand", label: "Brand", optionsKey: "brands" },
    { key: "gender", label: "Gender", optionsKey: "genders" },
    { key: "color", label: "Color", optionsKey: "colors" },
    { key: "style", label: "Style", optionsKey: "style_tags" },
    { key: "fit", label: "Fit", optionsKey: "fits" },
];

const SIZE_OPTIONS = [
    { value: "1024x1536", label: "Portrait (1024×1536)" },
    { value: "1024x1024", label: "Square (1024×1024)" },
    { value: "1536x1024", label: "Landscape (1536×1024)" },
];

const QUALITY_OPTIONS = [
    { value: "high", label: "High" },
    { value: "medium", label: "Medium" },
    { value: "low", label: "Low" },
];

export default function PlaygroundPage() {
    // catalog
    const [filters, setFilters] = useState({});
    const [filterOptions, setFilterOptions] = useState(null);
    const [results, setResults] = useState(null);
    const [offset, setOffset] = useState(0);
    const [loading, setLoading] = useState(false);

    // selection
    const [selected, setSelected] = useState(new Map());

    // prompt + params
    const [prompt, setPrompt] = useState("");
    const [size, setSize] = useState("1024x1536");
    const [quality, setQuality] = useState("high");
    const [count, setCount] = useState(1);
    const [advancedOpen, setAdvancedOpen] = useState(false);

    // generation
    const [generating, setGenerating] = useState(false);
    const [generatedImages, setGeneratedImages] = useState([]);
    const [genError, setGenError] = useState(null);

    useEffect(() => {
        runSearch(0);
        getCatalogFilterOptions().then(setFilterOptions).catch(() => {});
    }, []);

    async function runSearch(newOffset) {
        setLoading(true);
        try {
            const data = await searchCatalog({ ...filters, limit: LIMIT, offset: newOffset });
            setResults(data);
            setOffset(newOffset);
        } catch (err) {
            toast.error(err.message);
        } finally {
            setLoading(false);
        }
    }

    function toggleSelect(item) {
        setSelected((prev) => {
            const next = new Map(prev);
            if (next.has(item.id)) {
                next.delete(item.id);
                return next;
            }
            if (next.size >= MAX_SELECTED) {
                toast.error(`Maximum ${MAX_SELECTED} items can be selected`);
                return prev;
            }
            next.set(item.id, item);
            return next;
        });
    }

    function clearSelection() {
        setSelected(new Map());
    }

    async function handleGenerate() {
        setGenError(null);
        setGeneratedImages([]);
        if (selected.size === 0) {
            toast.error("Pick at least one catalog item");
            return;
        }
        if (!prompt.trim()) {
            toast.error("Prompt cannot be empty");
            return;
        }
        setGenerating(true);
        try {
            const data = await generatePlaygroundImage({
                catalog_item_ids: Array.from(selected.keys()),
                prompt,
                size,
                quality,
                n: count,
            });
            setGeneratedImages(data.images);
            toast.success(`Generated ${data.images.length} image(s) in ${data.elapsed_ms}ms`);
        } catch (err) {
            setGenError(err.message);
            toast.error(err.message);
        } finally {
            setGenerating(false);
        }
    }

    function downloadImage(dataUrl, index) {
        const link = document.createElement("a");
        link.href = dataUrl;
        link.download = `playground-${Date.now()}-${index}.png`;
        link.click();
    }

    const total = results?.total ?? 0;
    const totalPages = Math.ceil(total / LIMIT);
    const currentPage = Math.floor(offset / LIMIT) + 1;
    const canGenerate = selected.size > 0 && prompt.trim().length > 0 && !generating;

    return (
        <div className="space-y-6">
            <div>
                <h1 className="text-2xl font-bold text-white flex items-center gap-2">
                    <Sparkles className="w-5 h-5 text-indigo-400" />
                    Playground
                </h1>
                <p className="text-slate-400 mt-1">
                    Pick catalog items, write a prompt, and generate images via gpt-image-2.
                    Nothing here is persisted.
                </p>
            </div>

            {/* Selected items rail */}
            <Card className="bg-slate-900 border-slate-800 p-3 sticky top-0 z-10">
                <div className="flex items-center justify-between gap-3 mb-2">
                    <p className="text-xs text-slate-400">
                        Selected: {selected.size} / {MAX_SELECTED}
                    </p>
                    {selected.size > 0 && (
                        <Button
                            size="sm"
                            variant="outline"
                            onClick={clearSelection}
                            className="border-slate-700 text-slate-300 hover:bg-slate-800 h-7"
                        >
                            <X className="w-3 h-3 mr-1" /> Clear all
                        </Button>
                    )}
                </div>
                {selected.size === 0 ? (
                    <p className="text-xs text-slate-500 italic">No items selected yet.</p>
                ) : (
                    <div className="flex gap-2 overflow-x-auto pb-1">
                        {Array.from(selected.values()).map((item) => (
                            <div key={item.id} className="relative shrink-0 w-16 h-16">
                                <img
                                    src={item.image_front_url}
                                    alt={item.name}
                                    className="w-full h-full object-cover rounded border border-slate-700"
                                />
                                <button
                                    onClick={() => toggleSelect(item)}
                                    className="absolute -top-1 -right-1 w-5 h-5 rounded-full bg-slate-800 border border-slate-600 text-slate-200 hover:bg-red-700 flex items-center justify-center"
                                    aria-label={`Remove ${item.name}`}
                                >
                                    <X className="w-3 h-3" />
                                </button>
                            </div>
                        ))}
                    </div>
                )}
            </Card>

            {/* Catalog picker */}
            <Card className="bg-slate-900 border-slate-800 p-4 space-y-4">
                <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-7 gap-3">
                    {FILTER_FIELDS.map(({ key, label, optionsKey }) => {
                        const options = filterOptions?.[optionsKey] ?? [];
                        return (
                            <div key={key} className="space-y-1">
                                <Label className="text-xs text-slate-400">{label}</Label>
                                <select
                                    value={filters[key] || ""}
                                    onChange={(e) => setFilters({ ...filters, [key]: e.target.value })}
                                    className="w-full h-8 px-2 text-sm rounded-md bg-slate-800 border border-slate-700 text-slate-100 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                                >
                                    <option value="">All</option>
                                    {options.map((opt) => (
                                        <option key={opt} value={opt}>{opt}</option>
                                    ))}
                                </select>
                            </div>
                        );
                    })}
                    <div className="flex items-end">
                        <Button
                            size="sm"
                            onClick={() => runSearch(0)}
                            disabled={loading}
                            className="w-full bg-indigo-600 hover:bg-indigo-700"
                        >
                            {loading ? <Loader2 className="w-3 h-3 animate-spin" /> : <Search className="w-3 h-3 mr-1" />}
                            Search
                        </Button>
                    </div>
                </div>

                {loading && (
                    <div className="grid grid-cols-2 sm:grid-cols-4 md:grid-cols-6 gap-3">
                        {Array.from({ length: 12 }).map((_, i) => (
                            <Skeleton key={i} className="aspect-square w-full bg-slate-800 rounded-md" />
                        ))}
                    </div>
                )}

                {!loading && results && (
                    <>
                        <div className="grid grid-cols-2 sm:grid-cols-4 md:grid-cols-6 gap-3">
                            {results.items.map((item) => {
                                const isSelected = selected.has(item.id);
                                return (
                                    <button
                                        key={item.id}
                                        onClick={() => toggleSelect(item)}
                                        className={`relative group rounded-md overflow-hidden border transition-all text-left ${
                                            isSelected
                                                ? "border-indigo-500 ring-2 ring-indigo-500"
                                                : "border-slate-700 hover:border-slate-500"
                                        }`}
                                    >
                                        <div className="aspect-square bg-slate-800">
                                            {item.image_front_url ? (
                                                <img
                                                    src={item.image_front_url}
                                                    alt={item.name}
                                                    className="w-full h-full object-cover"
                                                />
                                            ) : (
                                                <div className="w-full h-full flex items-center justify-center">
                                                    <ImageIcon className="w-6 h-6 text-slate-600" />
                                                </div>
                                            )}
                                        </div>
                                        {isSelected && (
                                            <div className="absolute top-1 right-1 w-5 h-5 rounded-full bg-indigo-600 flex items-center justify-center">
                                                <Check className="w-3 h-3 text-white" />
                                            </div>
                                        )}
                                        <div className="p-2 bg-slate-900">
                                            <p className="text-xs text-slate-100 truncate">{item.name}</p>
                                            <p className="text-[10px] text-slate-500 truncate">{item.brand}</p>
                                        </div>
                                    </button>
                                );
                            })}
                        </div>

                        {totalPages > 1 && (
                            <div className="flex items-center justify-between text-sm text-slate-400">
                                <span>{total} items</span>
                                <div className="flex items-center gap-2">
                                    <Button
                                        variant="outline"
                                        size="sm"
                                        disabled={currentPage === 1}
                                        onClick={() => runSearch(offset - LIMIT)}
                                        className="border-slate-700 text-slate-300 hover:bg-slate-800 h-7"
                                    >
                                        <ChevronLeft className="w-3 h-3" />
                                    </Button>
                                    <span>Page {currentPage} / {totalPages}</span>
                                    <Button
                                        variant="outline"
                                        size="sm"
                                        disabled={currentPage === totalPages}
                                        onClick={() => runSearch(offset + LIMIT)}
                                        className="border-slate-700 text-slate-300 hover:bg-slate-800 h-7"
                                    >
                                        <ChevronRight className="w-3 h-3" />
                                    </Button>
                                </div>
                            </div>
                        )}
                    </>
                )}
            </Card>

            {/* Prompt */}
            <Card className="bg-slate-900 border-slate-800 p-4 space-y-2">
                <Label className="text-xs text-slate-400">Prompt</Label>
                <Textarea
                    value={prompt}
                    onChange={(e) => setPrompt(e.target.value)}
                    rows={6}
                    placeholder="Describe how to render the selected items. e.g. 'Place these clothes on a young woman walking down a Paris street, photorealistic, golden hour.'"
                    className="bg-slate-800 border-slate-700 text-slate-100 placeholder:text-slate-500 resize-none"
                />
                <p className="text-xs text-slate-500">{prompt.length} / 2000</p>
            </Card>

            {/* Advanced */}
            <Card className="bg-slate-900 border-slate-800 p-4">
                <button
                    onClick={() => setAdvancedOpen((v) => !v)}
                    className="flex items-center gap-2 text-sm text-slate-300 hover:text-white"
                    aria-expanded={advancedOpen}
                >
                    {advancedOpen ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
                    Advanced
                </button>

                {advancedOpen && (
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-3 mt-3">
                        <div className="space-y-1">
                            <Label className="text-xs text-slate-400">Size</Label>
                            <select
                                value={size}
                                onChange={(e) => setSize(e.target.value)}
                                className="w-full h-9 px-2 text-sm rounded-md bg-slate-800 border border-slate-700 text-slate-100"
                            >
                                {SIZE_OPTIONS.map((o) => (
                                    <option key={o.value} value={o.value}>{o.label}</option>
                                ))}
                            </select>
                        </div>
                        <div className="space-y-1">
                            <Label className="text-xs text-slate-400">Quality</Label>
                            <select
                                value={quality}
                                onChange={(e) => setQuality(e.target.value)}
                                className="w-full h-9 px-2 text-sm rounded-md bg-slate-800 border border-slate-700 text-slate-100"
                            >
                                {QUALITY_OPTIONS.map((o) => (
                                    <option key={o.value} value={o.value}>{o.label}</option>
                                ))}
                            </select>
                        </div>
                        <div className="space-y-1">
                            <Label className="text-xs text-slate-400">Count</Label>
                            <Input
                                type="number"
                                min={1}
                                max={4}
                                value={count}
                                onChange={(e) =>
                                    setCount(Math.max(1, Math.min(4, Number(e.target.value) || 1)))
                                }
                                className="bg-slate-800 border-slate-700 text-slate-100 h-9 text-sm"
                            />
                        </div>
                    </div>
                )}
            </Card>

            {/* Generate */}
            <div>
                <Button
                    onClick={handleGenerate}
                    disabled={!canGenerate}
                    className="bg-indigo-600 hover:bg-indigo-700 disabled:opacity-40"
                >
                    {generating ? (
                        <><Loader2 className="w-4 h-4 animate-spin mr-2" /> Generating…</>
                    ) : (
                        <><Sparkles className="w-4 h-4 mr-2" /> Generate</>
                    )}
                </Button>
            </div>

            {/* Result */}
            {(generating || generatedImages.length > 0 || genError) && (
                <Card className="bg-slate-900 border-slate-800 p-4 space-y-3">
                    <CardTitle className="text-sm font-medium text-slate-300">Result</CardTitle>
                    {generating && (
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                            {Array.from({ length: count }).map((_, i) => (
                                <Skeleton key={i} className="aspect-[2/3] w-full bg-slate-800 rounded-md" />
                            ))}
                        </div>
                    )}
                    {!generating && generatedImages.length > 0 && (
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                            {generatedImages.map((dataUrl, i) => (
                                <div key={i} className="space-y-2">
                                    <img
                                        src={dataUrl}
                                        alt={`Generated ${i + 1}`}
                                        className="w-full rounded-md border border-slate-700"
                                    />
                                    <Button
                                        variant="outline"
                                        size="sm"
                                        onClick={() => downloadImage(dataUrl, i)}
                                        className="border-slate-700 text-slate-300 hover:bg-slate-800"
                                    >
                                        <Download className="w-3 h-3 mr-1" /> Download
                                    </Button>
                                </div>
                            ))}
                        </div>
                    )}
                    {!generating && genError && (
                        <Alert variant="destructive" className="bg-red-950 border-red-800">
                            <AlertCircle className="h-4 w-4" />
                            <AlertDescription>{genError}</AlertDescription>
                        </Alert>
                    )}
                </Card>
            )}
        </div>
    );
}
```

- [ ] **Step 3: Commit**

```bash
git add admin/src/app/playground/page.js
git commit -m "feat(admin): playground page with item picker, prompt, and result grid"
```

---

## Task 10: End-to-end smoke verification

**Files:** none (manual verification per project CLAUDE.md)

- [ ] **Step 1: Start the backend**

In one terminal:
```bash
cd backend && uvicorn app.main:app --reload --port 8000
```
Expected: server starts; `/playground/generate-image` appears in the OpenAPI docs at `http://localhost:8000/docs`.

- [ ] **Step 2: Start the admin dev server**

In a second terminal:
```bash
cd admin && npm run dev
```
Expected: dev server up at `http://localhost:3000`.

- [ ] **Step 3: Confirm proxy is reachable**

Run: `curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8317/v1/models -H "Authorization: Bearer dummy"`
Expected: `200` or `401` (proxy is up; auth status doesn't matter for liveness).

If the proxy isn't running, the test in step 6 will fail with a 502/504 — that's fine, the goal here is only to verify the round-trip works once the proxy is up.

- [ ] **Step 4: Visual checks (no generation)**

In the browser, log in to the admin panel and click **Playground** in the sidebar.
- Verify the new sidebar entry is present and active when on `/playground`.
- Verify the empty selection rail says "No items selected yet."
- Verify the catalog grid loads with thumbnails.
- Click 2-3 items: each gets the indigo ring + checkmark; each appears in the rail with an X to remove.
- Click an "X" in the rail: item is deselected in the grid too.
- Verify the Generate button is disabled when prompt is empty.
- Type a prompt: button enables.
- Open Advanced: the size/quality/count controls render. Change them.

- [ ] **Step 5: Generation round-trip**

Pick 1-3 items, type a real prompt (e.g. "place these clothes on a young woman walking down a Paris street, photorealistic"), click Generate.

Expected:
- Button shows the spinner; result card shows skeletons.
- After ~10-60s the generated image renders in the result grid.
- A success toast reports `Generated N image(s) in Xms`.
- Download button downloads a `.png`.

If the proxy is down or the model rejects the request, the result card shows a red alert with the upstream error message — that's the error path working.

- [ ] **Step 6: Persistence sanity check**

In a `psql` shell against the dev DB (or sqlite if local):
```sql
SELECT count(*) FROM catalog_items;
```
Expected: count is the same before and after a generation (no rows added by playground).

- [ ] **Step 7: Run the full backend test suite again**

Run: `cd backend && pytest -q`
Expected: all tests PASS.

- [ ] **Step 8: Commit any housekeeping**

If steps 4-6 surfaced a small UI fix, commit it now:
```bash
git add admin/src/app/playground/page.js
git commit -m "fix(admin/playground): <describe fix>"
```
Otherwise, no commit needed.

---

## Self-Review Notes

**Spec coverage**

| Spec section                                | Task         |
| ------------------------------------------- | ------------ |
| 4.1 File structure (backend create/modify)  | 1, 2, 3, 4, 5, 6 |
| 4.1 File structure (frontend)               | 7, 8, 9      |
| 4.2 Endpoint contract (request/response)    | 1, 5         |
| 4.3 Data flow (download → multipart → b64)  | 3, 5         |
| 4.4 Configuration (CODEX_PROXY_URL/KEY)     | 2            |
| 4.5 Reference image source (image_front_url)| 5            |
| 5.1-5.4 Frontend layout / sidebar / state   | 8, 9         |
| 6.1 Schema                                  | 1            |
| 6.2 Service                                 | 3, 4         |
| 6.3 Router                                  | 5, 6         |
| 7 Error handling table                      | 4, 5, 6      |
| 8.1 Backend tests (8 enumerated)            | 3, 4, 5, 6   |
| 8.2 Frontend manual verification            | 10           |
| 10 Acceptance criteria                      | 10           |

**No placeholders verified.** Every code block is concrete; no "TBD" / "implement later" / "similar to Task N".

**Type / signature consistency.** `generate_outfit_image(reference_urls, prompt, size, quality, n)` is defined in Task 3, error-wrapped in Task 4, called by keyword in Task 5, and patched by keyword in Task 6 — names match. `PlaygroundGenerateRequest` and `PlaygroundGenerateResponse` defined in Task 1 are used in Task 5. `CodexProxyError` / `CodexProxyTimeout` / `ReferenceImageError` defined in Task 3 (re-tightened in Task 4) are caught by name in Task 5 and patched in Task 6.

**Backend test count cross-check.** Spec §8.1 enumerates 8 tests; this plan creates 8 (3 in test_codex_image_service.py: happy + 2 errors via test ergonomics; plus 7 in test_playground.py: happy + 401 + 404 + 422×3 + 502 + 504 = 11 — meets and exceeds the spec list).

**Order of operations.** Schemas → settings → service (with tests) → router (with tests) → frontend api → sidebar → page → smoke. No task depends on a later task.
