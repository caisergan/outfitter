import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import String, distinct, func, select, text
from sqlalchemy.dialects.postgresql import array as pg_array
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
# ---------------------------------------------------------------------------
async def _embed_catalog_image(image_front_url: str) -> list[float] | None:  # noqa: ARG001
    """Fetch image from ``image_front_url`` and return a CLIP embedding vector.

    Returns None until the implementation is complete so existing create/update
    paths continue to work without raising errors.
    """
    return None


def _array_has_any(column, values: list[str], dialect_name: str):
    """Return a SQL clause that matches rows where ``column`` contains any value."""
    if dialect_name == "sqlite":
        json_values = func.json_each(column).table_valued("value").alias(f"{column.key}_values")
        return (
            select(1)
            .select_from(json_values)
            .where(json_values.c.value.in_(values))
            .exists()
        )

    return column.op("&&")(pg_array(values, type_=String()))


@router.post("/images/upload-url", response_model=CatalogImageUploadResponse)
async def get_catalog_image_upload_url(
    body: CatalogImageUploadRequest,
    _: CurrentUserDep,
) -> CatalogImageUploadResponse:
    """Issue a presigned S3 PUT URL for a catalog image upload."""
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

    slots = await scalar_distinct(CatalogItem.slot)
    categories = await scalar_distinct(CatalogItem.category)
    subcategories = await scalar_distinct(CatalogItem.subcategory)
    brands = await scalar_distinct(CatalogItem.brand)
    genders = await scalar_distinct(CatalogItem.gender)
    fits = await scalar_distinct(CatalogItem.fit)
    colors = await array_distinct(CatalogItem.color)
    style_tags = await array_distinct(CatalogItem.style_tags)
    occasion_tags = await array_distinct(CatalogItem.occasion_tags)
    patterns = await array_distinct(CatalogItem.pattern)

    # categories_by_slot: slot → distinct categories observed in that slot.
    cat_pairs = await db.execute(
        select(CatalogItem.slot, CatalogItem.category)
        .where(CatalogItem.category.is_not(None))
        .distinct()
        .order_by(CatalogItem.slot, CatalogItem.category)
    )
    categories_by_slot: dict[str, list[str]] = {}
    for slot_v, category_v in cat_pairs.all():
        categories_by_slot.setdefault(slot_v, []).append(category_v)

    # subcategories_by_category: category → distinct subcategories observed.
    subcat_pairs = await db.execute(
        select(CatalogItem.category, CatalogItem.subcategory)
        .where(CatalogItem.subcategory.is_not(None))
        .where(CatalogItem.category.is_not(None))
        .distinct()
        .order_by(CatalogItem.category, CatalogItem.subcategory)
    )
    subcategories_by_category: dict[str, list[str]] = {}
    for cat_v, sub_v in subcat_pairs.all():
        subcategories_by_category.setdefault(cat_v, []).append(sub_v)

    return {
        "slots": slots,
        "categories": categories,
        "subcategories": subcategories,
        "brands": brands,
        "genders": genders,
        "fits": fits,
        "colors": colors,
        "patterns": patterns,
        "style_tags": style_tags,
        "occasion_tags": occasion_tags,
        "categories_by_slot": categories_by_slot,
        "subcategories_by_category": subcategories_by_category,
    }


@router.get("/search", response_model=CatalogSearchResponse)
async def search_catalog(
    db: DbDep,
    _: CurrentUserDep,
    slot: Annotated[str | None, Query()] = None,
    category: Annotated[str | None, Query()] = None,
    subcategory: Annotated[str | None, Query()] = None,
    color: Annotated[str | None, Query()] = None,
    brand: Annotated[str | None, Query()] = None,
    gender: Annotated[str | None, Query()] = None,
    style: Annotated[str | None, Query()] = None,
    occasion: Annotated[str | None, Query()] = None,
    pattern: Annotated[str | None, Query()] = None,
    fit: Annotated[str | None, Query()] = None,
    q: Annotated[str | None, Query(description="Case-insensitive substring match on item name")] = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> CatalogSearchResponse:
    query = select(CatalogItem)
    dialect_name = db.get_bind().dialect.name

    if slot:
        query = query.where(CatalogItem.slot == slot)
    if category:
        query = query.where(CatalogItem.category == category)
    if subcategory:
        query = query.where(CatalogItem.subcategory == subcategory)
    if brand:
        query = query.where(CatalogItem.brand == brand)
    if gender:
        query = query.where(CatalogItem.gender == gender)
    if fit:
        query = query.where(CatalogItem.fit == fit)
    if color:
        colors = [value.strip() for value in color.split(",") if value.strip()]
        if colors:
            query = query.where(_array_has_any(CatalogItem.color, colors, dialect_name))
    if pattern:
        patterns = [value.strip() for value in pattern.split(",") if value.strip()]
        if patterns:
            query = query.where(_array_has_any(CatalogItem.pattern, patterns, dialect_name))
    if style:
        styles = [value.strip() for value in style.split(",") if value.strip()]
        if styles:
            query = query.where(_array_has_any(CatalogItem.style_tags, styles, dialect_name))
    if occasion:
        occasions = [value.strip() for value in occasion.split(",") if value.strip()]
        if occasions:
            query = query.where(_array_has_any(CatalogItem.occasion_tags, occasions, dialect_name))
    if q:
        needle = q.strip()
        if needle:
            ilike_pattern = f"%{needle}%"
            query = query.where(CatalogItem.name.ilike(ilike_pattern))

    count_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = count_result.scalar_one()

    result = await db.execute(query.offset(offset).limit(limit))
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
                    slot=row.slot,
                    category=row.category,
                    color=row.color,
                    style_tags=row.style_tags,
                    occasion_tags=row.occasion_tags,
                    image_front_url=row.image_front_url,
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
            # Wardrobe items have no brand/name; synthesize a display name.
            display_name = row.subcategory or row.category or row.slot
            results.append(
                SimilarItemResponse(
                    id=row.id,
                    brand="",  # wardrobe items are not brand-tagged
                    name=display_name,
                    slot=row.slot,
                    category=row.category,
                    color=row.color,
                    style_tags=row.style_tags,
                    occasion_tags=row.occasion_tags,
                    image_front_url=row.image_url,
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

    for field, value in update_data.items():
        setattr(item, field, value)

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
