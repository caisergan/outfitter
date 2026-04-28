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
