from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.jwt import get_current_user
from app.database import get_db
from app.models.catalog import CatalogItem
from app.models.outfit import SavedOutfit
from app.models.user import User
from app.models.wardrobe import WardrobeItem
from app.schemas.outfit import (
    OutfitListResponse,
    SaveOutfitRequest,
    SavedOutfitResponse,
    SuggestOutfitsRequest,
    SuggestOutfitsResponse,
)

router = APIRouter(prefix="/outfits", tags=["outfits"])

DbDep = Annotated[AsyncSession, Depends(get_db)]
CurrentUserDep = Annotated[User, Depends(get_current_user)]


@router.post("/suggest", response_model=SuggestOutfitsResponse)
async def suggest_outfits(
    body: SuggestOutfitsRequest,
    db: DbDep,
    current_user: CurrentUserDep,
) -> SuggestOutfitsResponse:
    from app.services.claude_service import suggest_outfits as claude_suggest

    available_items: list[dict] = []

    if body.source in ("catalog", "mix"):
        result = await db.execute(select(CatalogItem).limit(200))
        for item in result.scalars().all():
            available_items.append(
                {
                    "id": item.id,
                    "source": "catalog",
                    "brand": item.brand,
                    "category": item.category,
                    "name": item.name,
                    "color": item.color,
                    "style_tags": item.style_tags,
                    "fit": item.fit,
                    "image_url": item.image_front_url,
                }
            )

    if body.source in ("wardrobe", "mix"):
        result = await db.execute(
            select(WardrobeItem)
            .where(WardrobeItem.user_id == current_user.id)
            .where(WardrobeItem.deleted_at.is_(None))
            .limit(100)
        )
        for item in result.scalars().all():
            available_items.append(
                {
                    "id": item.id,
                    "source": "wardrobe",
                    "brand": None,
                    "category": item.category,
                    "name": item.subtype or item.category,
                    "color": item.color,
                    "style_tags": item.style_tags,
                    "fit": item.fit,
                    "image_url": item.image_url,
                }
            )

    params = body.model_dump(exclude_none=True)
    outfits = await claude_suggest(params, available_items)
    return SuggestOutfitsResponse(outfits=outfits)


@router.get("", response_model=OutfitListResponse)
async def list_outfits(
    db: DbDep,
    current_user: CurrentUserDep,
) -> OutfitListResponse:
    result = await db.execute(
        select(SavedOutfit)
        .where(SavedOutfit.user_id == current_user.id)
        .order_by(SavedOutfit.created_at.desc())
    )
    items = result.scalars().all()
    return OutfitListResponse(items=[SavedOutfitResponse.model_validate(i) for i in items])


@router.post("", response_model=SavedOutfitResponse, status_code=status.HTTP_201_CREATED)
async def save_outfit(
    body: SaveOutfitRequest,
    db: DbDep,
    current_user: CurrentUserDep,
) -> SavedOutfitResponse:
    outfit = SavedOutfit(
        user_id=current_user.id,
        source=body.source,
        slots=body.slots,
        generated_image_url=body.generated_image_url,
    )
    db.add(outfit)
    await db.flush()
    await db.refresh(outfit)
    return SavedOutfitResponse.model_validate(outfit)


@router.delete("/{outfit_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_outfit(
    outfit_id: str,
    db: DbDep,
    current_user: CurrentUserDep,
) -> None:
    result = await db.execute(select(SavedOutfit).where(SavedOutfit.id == outfit_id))
    outfit = result.scalar_one_or_none()

    if not outfit:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Outfit not found")
    if outfit.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

    await db.delete(outfit)
    await db.flush()
