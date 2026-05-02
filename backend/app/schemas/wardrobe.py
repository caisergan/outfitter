import uuid
from datetime import datetime
from pydantic import BaseModel, field_validator

from app.schemas.catalog import (
    CATALOG_SLOT,
    CATALOG_CATEGORY,
    CATALOG_PATTERN,
    CATALOG_FIT,
    CATALOG_STYLE_TAG,
    CATALOG_OCCASION_TAG,
)


class WardrobeItemCreate(BaseModel):
    slot: CATALOG_SLOT
    category: CATALOG_CATEGORY | None = None
    subcategory: str | None = None
    color: list[str] | None = None
    pattern: list[CATALOG_PATTERN] | None = None
    fit: CATALOG_FIT | None = None
    style_tags: list[CATALOG_STYLE_TAG] | None = None
    occasion_tags: list[CATALOG_OCCASION_TAG] | None = None
    image_url: str


class WardrobeTagResponse(BaseModel):
    """Returned by the AI tagging endpoint (POST /wardrobe/tag)."""

    slot: CATALOG_SLOT
    category: CATALOG_CATEGORY | None = None
    subcategory: str | None = None
    color: list[str] | None = None
    pattern: list[CATALOG_PATTERN] | None = None
    fit: CATALOG_FIT | None = None
    style_tags: list[CATALOG_STYLE_TAG] | None = None
    occasion_tags: list[CATALOG_OCCASION_TAG] | None = None
    confidence: float
    image_url: str | None = None


class WardrobeItemResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    slot: str
    category: str | None
    subcategory: str | None
    color: list[str]
    pattern: list[str]
    fit: str | None
    style_tags: list[str]
    occasion_tags: list[str]
    image_url: str
    times_used: int
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}

    @field_validator("color", "pattern", "style_tags", "occasion_tags", mode="before")
    @classmethod
    def normalize_list(cls, v: list[str] | None) -> list[str]:
        return v if v is not None else []


class WardrobeListResponse(BaseModel):
    items: list[WardrobeItemResponse]
    total: int
