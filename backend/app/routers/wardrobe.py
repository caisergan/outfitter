import asyncio
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
    slot: Annotated[str | None, Query()] = None,
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
    if slot:
        q = q.where(WardrobeItem.slot == slot)
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

    from uuid import uuid4
    from app.services.image_service import clean_and_crop_image
    from app.services.gemini_service import tag_wardrobe_item_with_gemini
    from app.services.storage_service import upload_bytes, get_public_url

    # 1. Background removal (CPU intensive, run in thread to not block event loop)
    cleaned_bytes = await asyncio.to_thread(clean_and_crop_image, image_bytes)

    # 2. Extract tags using Gemini AI using the clean garment
    tags = await tag_wardrobe_item_with_gemini(cleaned_bytes, "image/png")

    # 3. Upload the cleaned image to S3 immediately
    image_id = str(uuid4())
    key = f"wardrobe/{current_user.id}/{image_id}.png"
    await asyncio.to_thread(upload_bytes, key, cleaned_bytes, "image/png")

    # 4. Return the public URL so the frontend can display it
    tags["image_url"] = get_public_url(key)

    return WardrobeTagResponse(**tags)


@router.post("", response_model=WardrobeItemResponse, status_code=status.HTTP_201_CREATED)
async def create_wardrobe_item(
    body: WardrobeItemCreate,
    db: DbDep,
    current_user: CurrentUserDep,
) -> WardrobeItemResponse:
    """
    Creates a new wardrobe item. Fetches the image from the provided URL
    (or storage key) to compute its CLIP embedding for visual search.
    """
    import logging
    from app.services.storage_service import download_bytes
    from app.services.clip_service import embed_image_async
    import httpx
    from urllib.parse import urlparse

    # 1. Fetch image bytes to compute embedding
    image_bytes = None
    embedding = None
    try:
        parsed_url = urlparse(body.image_url)
        path = parsed_url.path.lstrip('/')

        if "wardrobe" in path:
            # Try downloading directly from R2 via key
            image_bytes = await asyncio.to_thread(download_bytes, path)
        else:
            async with httpx.AsyncClient(timeout=10) as client:
                resp = await client.get(body.image_url)
                resp.raise_for_status()
                image_bytes = resp.content

        if image_bytes:
            embedding = await embed_image_async(image_bytes)
        else:
            logging.getLogger(__name__).warning(f"No image bytes found for {body.image_url}")
    except Exception as e:
        logging.getLogger(__name__).exception(f"Could not compute embedding for {body.image_url}: {e}")
        embedding = None

    # 2. Save to database
    item = WardrobeItem(
        user_id=current_user.id,
        slot=body.slot,
        category=body.category,
        subcategory=body.subcategory,
        color=body.color,
        pattern=body.pattern,
        fit=body.fit,
        style_tags=body.style_tags,
        occasion_tags=body.occasion_tags,
        image_url=body.image_url,
        clip_embedding=embedding,
        times_used=0,
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
