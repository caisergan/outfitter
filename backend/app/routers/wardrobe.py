import io
from typing import Annotated

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.jwt import get_current_user
from app.database import get_db
from app.models.user import User
from app.models.wardrobe import WardrobeItem
from app.schemas.wardrobe import (
    WardrobeItemCreate,
    WardrobeItemResponse,
    WardrobeListResponse,
    WardrobeTagResponse,
)

router = APIRouter(prefix="/wardrobe", tags=["wardrobe"])

DbDep = Annotated[AsyncSession, Depends(get_db)]
CurrentUserDep = Annotated[User, Depends(get_current_user)]

ALLOWED_TYPES = {"image/jpeg", "image/png"}
MAX_FILE_BYTES = 10 * 1024 * 1024  # 10 MB


@router.get("", response_model=WardrobeListResponse)
async def list_wardrobe(
    db: DbDep,
    current_user: CurrentUserDep,
    category: Annotated[str | None, Query()] = None,
    sort: Annotated[str, Query()] = "recent",
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> WardrobeListResponse:
    q = (
        select(WardrobeItem)
        .where(WardrobeItem.user_id == current_user.id)
        .where(WardrobeItem.deleted_at.is_(None))
    )
    if category:
        q = q.where(WardrobeItem.category == category)

    if sort == "color":
        q = q.order_by(WardrobeItem.color)
    else:
        q = q.order_by(WardrobeItem.created_at.desc())

    count_result = await db.execute(select(func.count()).select_from(q.subquery()))
    total = count_result.scalar_one()

    result = await db.execute(q.offset(offset).limit(limit))
    items = result.scalars().all()

    return WardrobeListResponse(
        items=[WardrobeItemResponse.model_validate(i) for i in items],
        total=total,
    )


@router.post("/tag", response_model=WardrobeTagResponse)
async def tag_wardrobe_item(
    current_user: CurrentUserDep,
    file: UploadFile = File(),
) -> WardrobeTagResponse:
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Only JPEG and PNG images are accepted",
        )

    image_bytes = await file.read()
    if len(image_bytes) > MAX_FILE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="File exceeds 10 MB limit",
        )

    from app.services.claude_service import tag_wardrobe_item as claude_tag

    tags = await claude_tag(image_bytes, file.content_type)
    return WardrobeTagResponse(**tags)


@router.post("", response_model=WardrobeItemResponse, status_code=status.HTTP_201_CREATED)
async def create_wardrobe_item(
    body: WardrobeItemCreate,
    db: DbDep,
    current_user: CurrentUserDep,
) -> WardrobeItemResponse:
    from app.services.storage_service import get_signed_read_url
    from app.services.clip_service import embed_image_async
    import httpx

    # Fetch image bytes to compute embedding
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(body.image_url)
            resp.raise_for_status()
            image_bytes = resp.content
        embedding = await embed_image_async(image_bytes)
    except Exception:
        embedding = None

    item = WardrobeItem(
        user_id=current_user.id,
        category=body.category,
        subtype=body.subtype,
        color=body.color,
        pattern=body.pattern,
        fit=body.fit,
        style_tags=body.style_tags,
        image_url=body.image_url,
        clip_embedding=embedding,
    )
    db.add(item)
    await db.flush()
    await db.refresh(item)
    return WardrobeItemResponse.model_validate(item)


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_wardrobe_item(
    item_id: str,
    db: DbDep,
    current_user: CurrentUserDep,
) -> None:
    from datetime import datetime, timezone

    result = await db.execute(
        select(WardrobeItem)
        .where(WardrobeItem.id == item_id)
        .where(WardrobeItem.deleted_at.is_(None))
    )
    item = result.scalar_one_or_none()

    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")
    if item.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

    item.deleted_at = datetime.now(timezone.utc)
    await db.flush()
