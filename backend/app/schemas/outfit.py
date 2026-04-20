import uuid
from datetime import datetime
from pydantic import BaseModel
from typing import Literal


class OutfitSlotItem(BaseModel):
    id: str
    name: str
    brand: str | None = None
    image_url: str


class OutfitSlots(BaseModel):
    top: OutfitSlotItem | None = None
    bottom: OutfitSlotItem | None = None
    shoes: OutfitSlotItem | None = None
    accessory: OutfitSlotItem | None = None
    outerwear: OutfitSlotItem | None = None
    bag: OutfitSlotItem | None = None


class SuggestOutfitsRequest(BaseModel):
    occasion: str | None = None
    season: str | None = None
    color_preference: str | None = None
    source: Literal["wardrobe", "catalog", "mix"] = "mix"


class OutfitSuggestion(BaseModel):
    slots: dict
    style_note: str


class SuggestOutfitsResponse(BaseModel):
    outfits: list[OutfitSuggestion]


class SaveOutfitRequest(BaseModel):
    source: Literal["playground", "assistant"]
    slots: dict
    generated_image_url: str | None = None


class SavedOutfitResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    source: str
    slots: dict
    generated_image_url: str | None
    created_at: datetime

    model_config = {"from_attributes": True}


class OutfitListResponse(BaseModel):
    items: list[SavedOutfitResponse]
