import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select, distinct, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.jwt import get_current_user
from app.database import get_db
from app.models.catalog import CatalogItem
from app.models.user import User
from app.schemas.catalog import (
    BulkInsertError,
    CatalogBulkCreateResponse,
    CatalogImageUploadRequest,
    CatalogImageUploadResponse,
    CatalogItemCreate,
    CatalogItemResponse,
    CatalogItemUpdate,
    CatalogSearchResponse,
    SimilarItemResponse,
    SimilarItemsResponse,
)
from app.services.storage_service import (
    IMAGE_UPLOAD_EXPIRES_IN,
    StorageError,
    get_catalog_upload_target,
)

router = APIRouter(prefix="/catalog", tags=["catalog"])

DbDep = Annotated[AsyncSession, Depends(get_db)]
CurrentUserDep = Annotated[User, Depends(get_current_user)]


# ---------------------------------------------------------------------------
# CLIP embedding helper
# TODO(clip): Implement this once embedding infrastructure is confirmed.
#   - Import embed_image_async from app.services.clip_service
#   - Fetch the image bytes via httpx before calling embed_image_async
#   - Handle HTTP/timeout errors and raise HTTPException(502) on failure
#   - Wire into create_catalog_item, bulk_create_catalog_items, update_catalog_item
# ---------------------------------------------------------------------------
async def _embed_catalog_image(image_url: str) -> list[float] | None:  # noqa: ARG001
    """Fetch image from ``image_url`` and return a CLIP embedding vector.

    TODO(clip): Replace this stub with a real implementation:

        import httpx
        from app.services.clip_service import embed_image_async

        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.get(image_url)
            response.raise_for_status()
        return await embed_image_async(response.content)

    Returns None until the implementation is complete so existing create/update
    paths continue to work without raising errors.
    """
    # TODO(clip): Remove this stub return once embedding is implemented.
    return None


@router.post("/images/upload-url", response_model=CatalogImageUploadResponse)
async def get_catalog_image_upload_url(
    body: CatalogImageUploadRequest,
    _: CurrentUserDep,
) -> CatalogImageUploadResponse:
    """Issue a presigned S3 PUT URL for a catalog image upload.

    The admin client should:
    1. Call this endpoint to get ``upload_url`` and ``image_url``.
    2. PUT the image file directly to ``upload_url`` (with the correct Content-Type header).
    3. Pass the returned ``image_url`` to POST /catalog/items or PATCH /catalog/items/{id}.
    """
    try:
        target = get_catalog_upload_target(
            brand=body.brand,
            filename=body.filename,
            content_type=body.content_type,
        )
    except StorageError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Storage service error: {exc}",
        ) from exc

    return CatalogImageUploadResponse(
        upload_url=target.upload_url,
        image_url=target.image_url,
        object_key=target.key,
        expires_in=IMAGE_UPLOAD_EXPIRES_IN,
    )


@router.get("/filter-options")
async def get_catalog_filter_options(db: DbDep, _: CurrentUserDep) -> dict:
    """Return distinct values for each filterable field to populate UI dropdowns."""

    async def scalar_distinct(col):
        res = await db.execute(
            select(distinct(col)).where(col.is_not(None)).order_by(col)
        )
        return res.scalars().all()

    async def array_distinct(col):
        unnested = select(func.unnest(col).label("val")).where(col.is_not(None)).subquery()
        res = await db.execute(
            select(distinct(unnested.c.val)).order_by(text("val"))
        )
        return res.scalars().all()

    categories = await scalar_distinct(CatalogItem.category)
    brands = await scalar_distinct(CatalogItem.brand)
    genders = await scalar_distinct(CatalogItem.gender)
    fits = await scalar_distinct(CatalogItem.fit)
    colors = await array_distinct(CatalogItem.color)
    style_tags = await array_distinct(CatalogItem.style_tags)

    return {
        "categories": categories,
        "brands": brands,
        "genders": genders,
        "fits": fits,
        "colors": colors,
        "style_tags": style_tags,
    }


@router.get("/search", response_model=CatalogSearchResponse)
async def search_catalog(
    db: DbDep,
    _: CurrentUserDep,
    category: Annotated[str | None, Query()] = None,
    color: Annotated[str | None, Query()] = None,
    brand: Annotated[str | None, Query()] = None,
    gender: Annotated[str | None, Query()] = None,
    style: Annotated[str | None, Query()] = None,
    fit: Annotated[str | None, Query()] = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> CatalogSearchResponse:
    q = select(CatalogItem)

    if category:
        q = q.where(CatalogItem.category == category)
    if brand:
        q = q.where(CatalogItem.brand == brand)
    if gender:
        q = q.where(CatalogItem.gender == gender)
    if fit:
        q = q.where(CatalogItem.fit == fit)
    if color:
        colors = [c.strip() for c in color.split(",")]
        q = q.where(CatalogItem.color.overlap(colors))
    if style:
        q = q.where(CatalogItem.style_tags.contains([style]))

    count_result = await db.execute(select(func.count()).select_from(q.subquery()))
    total = count_result.scalar_one()

    result = await db.execute(q.offset(offset).limit(limit))
    items = result.scalars().all()

    return CatalogSearchResponse(
        items=[CatalogItemResponse.model_validate(i) for i in items],
        total=total,
    )


@router.get("/similar/{item_id}", response_model=SimilarItemsResponse)
async def similar_items(
    item_id: str,
    db: DbDep,
    _: CurrentUserDep,
    limit: Annotated[int, Query(ge=1, le=50)] = 10,
    source: Annotated[str, Query()] = "catalog",
) -> SimilarItemsResponse:
    # Fetch source item embedding
    result = await db.execute(select(CatalogItem).where(CatalogItem.id == item_id))
    item = result.scalar_one_or_none()

    if not item or item.clip_embedding is None:
        return SimilarItemsResponse(items=[], total=0)

    embedding = item.clip_embedding

    results: list[SimilarItemResponse] = []

    if source in ("catalog", "both"):
        rows = await db.execute(
            select(
                CatalogItem,
                CatalogItem.clip_embedding.cosine_distance(embedding).label("distance"),
            )
            .where(CatalogItem.id != item_id)
            .where(CatalogItem.clip_embedding.is_not(None))
            .order_by("distance")
            .limit(limit)
        )
        for row, distance in rows.all():
            results.append(
                SimilarItemResponse(
                    id=row.id,
                    brand=row.brand,
                    name=row.name,
                    category=row.category,
                    color=row.color,
                    style_tags=row.style_tags,
                    image_url=row.image_url,
                    similarity=round(1 - distance, 4),
                )
            )

    if source in ("wardrobe", "both"):
        from app.models.wardrobe import WardrobeItem

        wardrobe_rows = await db.execute(
            select(
                WardrobeItem,
                WardrobeItem.clip_embedding.cosine_distance(embedding).label("distance"),
            )
            .where(WardrobeItem.clip_embedding.is_not(None))
            .where(WardrobeItem.deleted_at.is_(None))
            .order_by("distance")
            .limit(limit)
        )
        for row, distance in wardrobe_rows.all():
            results.append(
                SimilarItemResponse(
                    id=row.id,
                    brand="",  # wardrobe items are not brand-tagged
                    name=row.category,
                    category=row.category,
                    color=row.color,
                    style_tags=row.style_tags,
                    image_url=row.image_url,
                    similarity=round(1 - distance, 4),
                )
            )

    results.sort(key=lambda r: r.similarity, reverse=True)
    page = results[:limit]
    return SimilarItemsResponse(items=page, total=len(page))


@router.post("/items", response_model=CatalogItemResponse, status_code=status.HTTP_201_CREATED)
async def create_catalog_item(
    body: CatalogItemCreate,
    db: DbDep,
    _: CurrentUserDep,
) -> CatalogItemResponse:
    item = CatalogItem(**body.model_dump())
    # TODO(clip): Compute and persist clip_embedding at write time when an image_url is present.
    #   embedding = await _embed_catalog_image(body.image_url)
    #   item.clip_embedding = embedding
    db.add(item)
    await db.flush()
    await db.refresh(item)
    return CatalogItemResponse.model_validate(item)


@router.post("/items/bulk", response_model=CatalogBulkCreateResponse, status_code=status.HTTP_200_OK)
async def bulk_create_catalog_items(
    body: list[CatalogItemCreate],
    db: DbDep,
    _: CurrentUserDep,
) -> CatalogBulkCreateResponse:
    created_items: list[CatalogItemResponse] = []
    errors: list[BulkInsertError] = []

    for index, item_data in enumerate(body):
        try:
            item = CatalogItem(**item_data.model_dump())
            # TODO(clip): Compute clip_embedding per item here and collect embedding errors
            #   into the BulkInsertError list so callers can resubmit failing items.
            #   embedding = await _embed_catalog_image(item_data.image_url)
            #   item.clip_embedding = embedding
            db.add(item)
            await db.flush()
            await db.refresh(item)
            created_items.append(CatalogItemResponse.model_validate(item))
        except Exception as exc:
            await db.rollback()
            errors.append(BulkInsertError(index=index, detail=str(exc)))

    return CatalogBulkCreateResponse(
        created=len(created_items),
        failed=len(errors),
        items=created_items,
        errors=errors,
    )


@router.get("/items/{item_id}", response_model=CatalogItemResponse)
async def get_catalog_item(
    item_id: uuid.UUID,
    db: DbDep,
    _: CurrentUserDep,
) -> CatalogItemResponse:
    result = await db.execute(select(CatalogItem).where(CatalogItem.id == item_id))
    item = result.scalar_one_or_none()

    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")

    return CatalogItemResponse.model_validate(item)


@router.patch("/items/{item_id}", response_model=CatalogItemResponse)
async def update_catalog_item(
    item_id: uuid.UUID,
    body: CatalogItemUpdate,
    db: DbDep,
    _: CurrentUserDep,
) -> CatalogItemResponse:
    result = await db.execute(select(CatalogItem).where(CatalogItem.id == item_id))
    item = result.scalar_one_or_none()

    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")

    update_data = body.model_dump(exclude_unset=True)
    image_url_changed = "image_url" in update_data

    for field, value in update_data.items():
        setattr(item, field, value)

    # TODO(clip): Recompute clip_embedding only when image_url changed.
    #   if image_url_changed and item.image_url:
    #       item.clip_embedding = await _embed_catalog_image(item.image_url)
    _ = image_url_changed  # remove once TODO(clip) is implemented

    await db.flush()
    await db.refresh(item)
    return CatalogItemResponse.model_validate(item)


@router.delete("/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_catalog_item(
    item_id: uuid.UUID,
    db: DbDep,
    _: CurrentUserDep,
) -> None:
    result = await db.execute(select(CatalogItem).where(CatalogItem.id == item_id))
    item = result.scalar_one_or_none()

    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")

    await db.delete(item)
    await db.flush()
