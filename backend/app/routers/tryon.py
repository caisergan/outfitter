import logging
import time
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
import redis.asyncio as redis

from app.auth.jwt import get_current_user
from app.config import settings
from app.database import get_db
from app.models.catalog import CatalogItem
from app.models.user import User
from app.models.wardrobe import WardrobeItem
from app.schemas.tryon import TryOnStatusResponse, TryOnSubmitRequest, TryOnSubmitResponse

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/tryon", tags=["tryon"])

DbDep = Annotated[AsyncSession, Depends(get_db)]
CurrentUserDep = Annotated[User, Depends(get_current_user)]

# Redis connection for rate limiting
redis_client = redis.from_url(settings.REDIS_URL, decode_responses=True)

RATE_LIMIT_MAX = 10
RATE_LIMIT_WINDOW = 60  # seconds


async def _check_rate_limit(user_id: str) -> None:
    key = f"rate_limit:tryon:{user_id}"
    try:
        # Use Redis atomic increment and expire
        async with redis_client.pipeline(transaction=True) as pipe:
            now = time.time()
            # Clean up old entries
            await pipe.zremrangebyscore(key, 0, now - RATE_LIMIT_WINDOW)
            # Add current hit
            await pipe.zadd(key, {str(now): now})
            # Count hits in window
            await pipe.zcard(key)
            # Set expiry on the whole set
            await pipe.expire(key, RATE_LIMIT_WINDOW)
            results = await pipe.execute()

        hit_count = results[2]
        if hit_count > RATE_LIMIT_MAX:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Rate limit exceeded: max 10 try-on requests per minute",
                headers={"Retry-After": "60"},
            )
    except (redis.RedisError, ConnectionError) as e:
        # Fallback: if Redis is down, log error but allow request to proceed
        # (Fail-open to avoid breaking service, alternatively fail-closed for strictness)
        logger.error("Redis rate limit error: %s", e)


async def _resolve_image_urls(
    slots: dict, db: AsyncSession, user_id: str
) -> dict[str, str]:
    urls: dict[str, str] = {}
    for slot_name, item_id in slots.items():
        if not item_id:
            continue
        # Try catalog first (catalog items are not user-scoped)
        result = await db.execute(select(CatalogItem).where(CatalogItem.id == item_id))
        item = result.scalar_one_or_none()
        if item:
            urls[slot_name] = item.image_url
            continue
        # Try wardrobe — filter by owner to prevent cross-user image resolution
        result = await db.execute(
            select(WardrobeItem).where(
                WardrobeItem.id == item_id,
                WardrobeItem.user_id == user_id,
            )
        )
        w_item = result.scalar_one_or_none()
        if w_item:
            urls[slot_name] = w_item.image_url
    return urls


@router.post("/submit", response_model=TryOnSubmitResponse, status_code=status.HTTP_202_ACCEPTED)
async def submit_tryon(
    body: TryOnSubmitRequest,
    db: DbDep,
    current_user: CurrentUserDep,
) -> TryOnSubmitResponse:
    await _check_rate_limit(str(current_user.id))

    from app.services.kling_service import submit_tryon as kling_submit

    outfit_image_urls = await _resolve_image_urls(body.slots, db, str(current_user.id))

    if not outfit_image_urls:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="No valid item IDs found in slots",
        )

    model_photo_url = body.user_photo_url or "default"
    job_id = await kling_submit(outfit_image_urls, model_photo_url)
    return TryOnSubmitResponse(job_id=job_id, status="pending")


@router.get("/status/{job_id}", response_model=TryOnStatusResponse)
async def tryon_status(
    job_id: str,
    current_user: CurrentUserDep,
) -> TryOnStatusResponse:
    from app.services.kling_service import poll_tryon_status

    result = await poll_tryon_status(job_id)
    return TryOnStatusResponse(
        job_id=job_id,
        status=result.get("status", "processing"),
        image_url=result.get("image_url"),
        error=result.get("error"),
    )
