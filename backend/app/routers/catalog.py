import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.jwt import get_current_user
from app.database import get_db
from app.models.catalog import CatalogItem
from app.models.user import User
from app.schemas.catalog import (
    BulkInsertError,
    CatalogBulkCreateResponse,
    CatalogItemCreate,
    CatalogItemResponse,
    CatalogItemUpdate,
    CatalogSearchResponse,
    SimilarItemResponse,
)

router = APIRouter(prefix="/catalog", tags=["catalog"])

DbDep = Annotated[AsyncSession, Depends(get_db)]
CurrentUserDep = Annotated[User, Depends(get_current_user)]


@router.get("/search", response_model=CatalogSearchResponse)
async def search_catalog(
    db: DbDep,
    _: CurrentUserDep,
    category: Annotated[str | None, Query()] = None,
    color: Annotated[str | None, Query()] = None,
    brand: Annotated[str | None, Query()] = None,
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


@router.get("/similar/{item_id}", response_model=list[SimilarItemResponse])
async def similar_items(
    item_id: str,
    db: DbDep,
    _: CurrentUserDep,
    limit: Annotated[int, Query(ge=1, le=50)] = 10,
    source: Annotated[str, Query()] = "catalog",
) -> list[SimilarItemResponse]:
    # Fetch source item embedding
    result = await db.execute(select(CatalogItem).where(CatalogItem.id == item_id))
    item = result.scalar_one_or_none()

    if not item or item.clip_embedding is None:
        return []

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
                    name=row.name,
                    category=row.category,
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
                    name=row.category,
                    category=row.category,
                    image_url=row.image_url,
                    similarity=round(1 - distance, 4),
                )
            )

    results.sort(key=lambda r: r.similarity, reverse=True)
    return results[:limit]


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

    for field, value in body.model_dump(exclude_unset=True).items():
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
