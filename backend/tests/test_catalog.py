from datetime import datetime, timezone
import uuid
from unittest.mock import patch

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
        gender="women",
        category="top",
        subtype="shirt",
        name="Linen Shirt",
        color=["blue"],
        pattern=None,
        fit="regular",
        style_tags=["casual"],
        image_front_url="https://example.com/catalog/linen-shirt.jpg",
        product_url="https://example.com/products/linen-shirt",
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )

    payload = CatalogItemResponse.model_validate(item).model_dump(mode="json")

    assert isinstance(item.id, uuid.UUID)
    assert payload["id"] == str(item.id)
    assert payload["gender"] == "women"


@pytest.mark.asyncio
async def test_catalog_search_returns_items_with_string_ids(client: AsyncClient, db):
    signup_resp = await _signup(client)
    token = signup_resp.json()["access_token"]

    item = CatalogItem(
        brand="Mango",
        gender="women",
        category="top",
        subtype="shirt",
        name="Linen Shirt",
        color=["blue"],
        pattern=None,
        fit="regular",
        style_tags=["casual"],
        image_front_url="https://example.com/catalog/linen-shirt.jpg",
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
    assert body["items"][0]["gender"] == "women"
    assert body["items"][0]["color"] == ["blue"]
    assert body["items"][0]["style_tags"] == ["casual"]


@pytest.mark.asyncio
async def test_catalog_search_filters_by_color_array_members(client: AsyncClient, db):
    signup_resp = await _signup(client, email="catalog-color-filter@outfitter.dev")
    token = signup_resp.json()["access_token"]

    matching_item = CatalogItem(
        brand="Mango",
        gender="women",
        category="dress",
        subtype="dress",
        name="Aqua Slip Dress",
        color=["Aqua Green", "White"],
        pattern=None,
        fit="regular",
        style_tags=["occasion"],
        image_front_url="https://example.com/catalog/aqua-slip-dress.jpg",
        product_url="https://example.com/products/aqua-slip-dress",
    )
    other_item = CatalogItem(
        brand="Mango",
        gender="women",
        category="dress",
        subtype="dress",
        name="Black Slip Dress",
        color=["Black"],
        pattern=None,
        fit="regular",
        style_tags=["occasion"],
        image_front_url="https://example.com/catalog/black-slip-dress.jpg",
        product_url="https://example.com/products/black-slip-dress",
    )
    db.add_all([matching_item, other_item])
    await db.commit()
    await db.refresh(matching_item)
    await db.refresh(other_item)

    response = await client.get(
        "/catalog/search?color=Aqua%20Green",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["total"] == 1
    assert body["items"][0]["id"] == str(matching_item.id)
    assert body["items"][0]["color"] == ["Aqua Green", "White"]


@pytest.mark.asyncio
async def test_catalog_search_filters_by_subtype(client: AsyncClient, db):
    signup_resp = await _signup(client, email="catalog-subtype-filter@outfitter.dev")
    token = signup_resp.json()["access_token"]

    shirt = CatalogItem(
        brand="Mango",
        gender="women",
        category="top",
        subtype="shirt",
        name="Linen Shirt",
        color=["white"],
        fit="regular",
        style_tags=["casual"],
        image_front_url="https://example.com/catalog/linen-shirt.jpg",
        product_url="https://example.com/products/linen-shirt",
    )
    tee = CatalogItem(
        brand="Mango",
        gender="women",
        category="top",
        subtype="t-shirt",
        name="Cotton Tee",
        color=["white"],
        fit="regular",
        style_tags=["casual"],
        image_front_url="https://example.com/catalog/cotton-tee.jpg",
        product_url="https://example.com/products/cotton-tee",
    )
    db.add_all([shirt, tee])
    await db.commit()
    await db.refresh(shirt)
    await db.refresh(tee)

    response = await client.get(
        "/catalog/search?subtype=shirt",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["total"] == 1
    assert body["items"][0]["id"] == str(shirt.id)
    assert body["items"][0]["subtype"] == "shirt"


@pytest.mark.asyncio
async def test_catalog_search_filters_by_name_query_case_insensitive(client: AsyncClient, db):
    signup_resp = await _signup(client, email="catalog-name-search@outfitter.dev")
    token = signup_resp.json()["access_token"]

    linen = CatalogItem(
        brand="Mango",
        gender="women",
        category="top",
        subtype="shirt",
        name="Linen Shirt",
        color=["white"],
        fit="regular",
        style_tags=["casual"],
        image_front_url="https://example.com/catalog/linen-shirt.jpg",
        product_url="https://example.com/products/linen-shirt",
    )
    cotton = CatalogItem(
        brand="Mango",
        gender="women",
        category="top",
        subtype="t-shirt",
        name="Cotton Tee",
        color=["white"],
        fit="regular",
        style_tags=["casual"],
        image_front_url="https://example.com/catalog/cotton-tee.jpg",
        product_url="https://example.com/products/cotton-tee",
    )
    db.add_all([linen, cotton])
    await db.commit()
    await db.refresh(linen)
    await db.refresh(cotton)

    response = await client.get(
        "/catalog/search?q=LINEN",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["total"] == 1
    assert body["items"][0]["id"] == str(linen.id)


@pytest.mark.asyncio
async def test_catalog_search_filters_by_style_tag_array_members(client: AsyncClient, db):
    signup_resp = await _signup(client, email="catalog-style-filter@outfitter.dev")
    token = signup_resp.json()["access_token"]

    matching_item = CatalogItem(
        brand="Mango",
        gender="women",
        category="top",
        subtype="shirt",
        name="Minimal Shirt",
        color=["White"],
        pattern=None,
        fit="regular",
        style_tags=["minimal", "office"],
        image_front_url="https://example.com/catalog/minimal-shirt.jpg",
        product_url="https://example.com/products/minimal-shirt",
    )
    other_item = CatalogItem(
        brand="Mango",
        gender="women",
        category="top",
        subtype="shirt",
        name="Boho Shirt",
        color=["Blue"],
        pattern=None,
        fit="regular",
        style_tags=["boho"],
        image_front_url="https://example.com/catalog/boho-shirt.jpg",
        product_url="https://example.com/products/boho-shirt",
    )
    db.add_all([matching_item, other_item])
    await db.commit()
    await db.refresh(matching_item)
    await db.refresh(other_item)

    response = await client.get(
        "/catalog/search?style=minimal",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["total"] == 1
    assert body["items"][0]["id"] == str(matching_item.id)
    assert body["items"][0]["style_tags"] == ["minimal", "office"]


# ---------------------------------------------------------------------------
# POST /catalog/images/upload-url
# ---------------------------------------------------------------------------


class TestCatalogImageUploadUrl:
    @pytest.mark.asyncio
    async def test_returns_upload_target_on_success(self, client: AsyncClient) -> None:
        signup_resp = await _signup(client, email="catalog-upload@outfitter.dev")
        token = signup_resp.json()["access_token"]

        with patch("app.routers.catalog.get_catalog_upload_target") as mock_target:
            mock_target.return_value.upload_url = "https://s3.amazonaws.com/presigned-put"
            mock_target.return_value.image_url = "https://cdn.example.com/catalog/nike/abc.jpg"
            mock_target.return_value.key = "catalog/nike/abc.jpg"

            response = await client.post(
                "/catalog/images/upload-url",
                headers={"Authorization": f"Bearer {token}"},
                json={
                    "brand": "Nike",
                    "filename": "sneaker.jpg",
                    "content_type": "image/jpeg",
                    "file_size": 2048,
                },
            )

        assert response.status_code == 200
        body = response.json()
        assert body["upload_url"] == "https://s3.amazonaws.com/presigned-put"
        assert body["image_url"] == "https://cdn.example.com/catalog/nike/abc.jpg"
        assert body["object_key"] == "catalog/nike/abc.jpg"
        assert body["expires_in"] == 900

    @pytest.mark.asyncio
    async def test_storage_error_returns_502(self, client: AsyncClient) -> None:
        signup_resp = await _signup(client, email="catalog-upload-502@outfitter.dev")
        token = signup_resp.json()["access_token"]

        from app.services.storage_service import StorageError

        with patch("app.routers.catalog.get_catalog_upload_target") as mock_target:
            mock_target.side_effect = StorageError("S3 unavailable")

            response = await client.post(
                "/catalog/images/upload-url",
                headers={"Authorization": f"Bearer {token}"},
                json={
                    "brand": "Nike",
                    "filename": "sneaker.jpg",
                    "content_type": "image/jpeg",
                    "file_size": 2048,
                },
            )

        assert response.status_code == 502
        assert "Storage service error" in response.json()["detail"]

    @pytest.mark.asyncio
    async def test_rejects_unsupported_content_type(self, client: AsyncClient) -> None:
        signup_resp = await _signup(client, email="catalog-upload-type@outfitter.dev")
        token = signup_resp.json()["access_token"]

        response = await client.post(
            "/catalog/images/upload-url",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "brand": "Nike",
                "filename": "sneaker.gif",
                "content_type": "image/gif",
                "file_size": 2048,
            },
        )

        assert response.status_code == 422
        assert "Unsupported content type" in response.text

    @pytest.mark.asyncio
    async def test_rejects_oversized_file(self, client: AsyncClient) -> None:
        signup_resp = await _signup(client, email="catalog-upload-size@outfitter.dev")
        token = signup_resp.json()["access_token"]

        response = await client.post(
            "/catalog/images/upload-url",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "brand": "Nike",
                "filename": "sneaker.jpg",
                "content_type": "image/jpeg",
                "file_size": 11 * 1024 * 1024,  # 11 MB — exceeds 10 MB limit
            },
        )

        assert response.status_code == 422
        assert "10 MB" in response.text


# ---------------------------------------------------------------------------
# Catalog image_front_url persistence through create / update / read
# ---------------------------------------------------------------------------


class TestCatalogImageFrontUrlPersistence:
    @pytest.mark.asyncio
    async def test_create_item_persists_image_front_url(self, client: AsyncClient, db) -> None:
        signup_resp = await _signup(client, email="catalog-persist@outfitter.dev")
        token = signup_resp.json()["access_token"]
        image_url = "https://cdn.example.com/catalog/nike/abc-123.jpg"

        response = await client.post(
            "/catalog/items",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "brand": "Nike",
                "gender": "women",
                "name": "Air Max 90",
                "category": "footwear",
                "image_front_url": image_url,
            },
        )

        assert response.status_code == 201
        assert response.json()["image_front_url"] == image_url
        assert response.json()["gender"] == "women"

    @pytest.mark.asyncio
    async def test_update_item_replaces_image_front_url(self, client: AsyncClient, db) -> None:
        signup_resp = await _signup(client, email="catalog-update-img@outfitter.dev")
        token = signup_resp.json()["access_token"]

        create_resp = await client.post(
            "/catalog/items",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "brand": "Nike",
                "gender": "men",
                "name": "Air Max 90",
                "category": "footwear",
                "image_front_url": "https://cdn.example.com/catalog/nike/old.jpg",
            },
        )
        item_id = create_resp.json()["id"]
        new_url = "https://cdn.example.com/catalog/nike/new.jpg"

        update_resp = await client.patch(
            f"/catalog/items/{item_id}",
            headers={"Authorization": f"Bearer {token}"},
            json={"image_front_url": new_url, "gender": "women"},
        )

        assert update_resp.status_code == 200
        assert update_resp.json()["image_front_url"] == new_url
        assert update_resp.json()["gender"] == "women"

    @pytest.mark.asyncio
    async def test_get_item_exposes_stored_image_front_url_unchanged(self, client: AsyncClient, db) -> None:
        signup_resp = await _signup(client, email="catalog-read-img@outfitter.dev")
        token = signup_resp.json()["access_token"]
        image_url = "https://cdn.example.com/catalog/nike/abc-123.jpg"

        create_resp = await client.post(
            "/catalog/items",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "brand": "Nike",
                "gender": "women",
                "name": "Air Max 90",
                "category": "footwear",
                "image_front_url": image_url,
            },
        )
        item_id = create_resp.json()["id"]

        get_resp = await client.get(
            f"/catalog/items/{item_id}",
            headers={"Authorization": f"Bearer {token}"},
        )

        assert get_resp.status_code == 200
        assert get_resp.json()["image_front_url"] == image_url
        assert get_resp.json()["gender"] == "women"

    @pytest.mark.asyncio
    async def test_search_exposes_stored_image_front_url_unchanged(self, client: AsyncClient, db) -> None:
        signup_resp = await _signup(client, email="catalog-search-img@outfitter.dev")
        token = signup_resp.json()["access_token"]
        image_url = "https://cdn.example.com/catalog/adidas/shoe.webp"

        await client.post(
            "/catalog/items",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "brand": "Adidas",
                "gender": "men",
                "name": "Stan Smith",
                "category": "footwear",
                "image_front_url": image_url,
            },
        )

        search_resp = await client.get(
            "/catalog/search?brand=Adidas",
            headers={"Authorization": f"Bearer {token}"},
        )

        assert search_resp.status_code == 200
        assert search_resp.json()["items"][0]["image_front_url"] == image_url
        assert search_resp.json()["items"][0]["gender"] == "men"
