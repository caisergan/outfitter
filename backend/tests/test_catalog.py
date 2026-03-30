from datetime import datetime, timezone
import uuid

import pytest
from httpx import AsyncClient

from app.models.catalog import CatalogItem
from app.schemas.catalog import CatalogItemResponse


async def _signup(
    client: AsyncClient,
    email: str = "catalog@outfitter.dev",
    password: str = "supersecret99",
):
    return await client.post("/auth/signup", json={"email": email, "password": password})


def test_catalog_item_response_serializes_uuid_without_mutating_model():
    item = CatalogItem(
        id=uuid.uuid4(),
        brand="Mango",
        category="top",
        subtype="shirt",
        name="Linen Shirt",
        color=["blue"],
        pattern=None,
        fit="regular",
        style_tags=["casual"],
        image_url="https://example.com/catalog/linen-shirt.jpg",
        product_url="https://example.com/products/linen-shirt",
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )

    payload = CatalogItemResponse.model_validate(item).model_dump(mode="json")

    assert isinstance(item.id, uuid.UUID)
    assert payload["id"] == str(item.id)


@pytest.mark.asyncio
async def test_catalog_search_returns_items_with_string_ids(client: AsyncClient, db):
    signup_resp = await _signup(client)
    token = signup_resp.json()["access_token"]

    item = CatalogItem(
        brand="Mango",
        category="top",
        subtype="shirt",
        name="Linen Shirt",
        color=["blue"],
        pattern=None,
        fit="regular",
        style_tags=["casual"],
        image_url="https://example.com/catalog/linen-shirt.jpg",
        product_url="https://example.com/products/linen-shirt",
    )
    db.add(item)
    await db.commit()
    await db.refresh(item)

    response = await client.get(
        "/catalog/search",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["total"] == 1
    assert body["items"][0]["id"] == str(item.id)
    assert body["items"][0]["color"] == ["blue"]
    assert body["items"][0]["style_tags"] == ["casual"]
