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
