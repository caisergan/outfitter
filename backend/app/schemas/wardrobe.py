import uuid
from datetime import datetime
from pydantic import BaseModel, Field


class WardrobeItemCreate(BaseModel):
    category: str
    subtype: str | None = None
    color: list[str] | None = None
    pattern: str | None = None
    fit: str | None = None
    season: list[str] | None = None
    material: list[str] | None = None
    occasion: list[str] | None = None
    primary_style: str | None = None
    style_tags: list[str] | None = None
    image_url: str


class WardrobeTagResponse(BaseModel):
    category: str
    subtype: str | None = None
    color: list[str] | None = None
    pattern: str | None = None
    fit: str | None = None
    season: list[str] | None = None
    material: list[str] | None = None
    occasion: list[str] | None = None
    primary_style: str | None = None
    style_tags: list[str] | None = None
    confidence: float
    image_url: str | None = None


class WardrobeItemResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    category: str
    subtype: str | None
    color: list[str] | None
    pattern: str | None
    fit: str | None
    season: list[str] | None
    material: list[str] | None
    occasion: list[str] | None
    primary_style: str | None
    style_tags: list[str] | None
    image_url: str
    times_used: int
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class WardrobeListResponse(BaseModel):
    items: list[WardrobeItemResponse]
    total: int
