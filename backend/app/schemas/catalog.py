import uuid
from datetime import datetime
from typing import Literal
from pydantic import BaseModel, field_validator

from app.services.storage_service import ALLOWED_CATALOG_CONTENT_TYPES

# Controlled taxonomy for catalog item categories.
# Downstream outfit and try-on flows treat category as controlled vocabulary,
# so we enforce it here at the API boundary rather than in the database.
CATALOG_CATEGORIES = Literal[
    "top",
    "bottom",
    "dress",
    "outerwear",
    "footwear",
    "accessory",
    "bag",
    "underwear",
    "swimwear",
    "activewear",
]
CATALOG_GENDERS = Literal["men", "women"]


class CatalogItemCreate(BaseModel):
    ref_code: str | None = None
    brand: str
    gender: CATALOG_GENDERS | None = None
    category: CATALOG_CATEGORIES
    subtype: str | None = None
    name: str
    color: list[str] | None = None
    pattern: str | None = None
    fit: str | None = None
    style_tags: list[str] | None = None
    image_url: str
    product_url: str | None = None


class CatalogItemUpdate(BaseModel):
    ref_code: str | None = None
    brand: str | None = None
    gender: CATALOG_GENDERS | None = None
    category: CATALOG_CATEGORIES | None = None
    subtype: str | None = None
    name: str | None = None
    color: list[str] | None = None
    pattern: str | None = None
    fit: str | None = None
    style_tags: list[str] | None = None
    image_url: str | None = None
    product_url: str | None = None


class CatalogItemResponse(BaseModel):
    id: uuid.UUID
    ref_code: str | None
    brand: str
    gender: str | None
    category: str
    subtype: str | None
    name: str
    color: list[str]
    pattern: str | None
    fit: str | None
    style_tags: list[str]
    image_url: str
    product_url: str | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}

    @field_validator("color", "style_tags", mode="before")
    @classmethod
    def normalize_list(cls, v: list[str] | None) -> list[str]:
        """Normalize None/null array fields to empty lists at the API boundary.

        Mobile and admin consumers declare these as non-optional lists, so
        returning null would cause deserialization failures on the client.
        """
        return v if v is not None else []


class CatalogSearchResponse(BaseModel):
    items: list[CatalogItemResponse]
    total: int


class CatalogFilterOptionsResponse(BaseModel):
    categories: list[str]
    subtypes: list[str]
    brands: list[str]
    genders: list[str]
    fits: list[str]
    patterns: list[str]
    colors: list[str]
    style_tags: list[str]


class SimilarItemResponse(BaseModel):
    """Item returned by /catalog/similar/{item_id}.

    Includes all fields required by the mobile CatalogItem model so that
    CatalogItem.fromJson() can deserialise both search and similar-items
    responses without a separate mobile model. The ``similarity`` field is
    extra and will be ignored by clients that do not consume it.
    """

    id: uuid.UUID
    brand: str
    name: str
    category: str
    color: list[str]
    style_tags: list[str]
    image_url: str
    similarity: float

    @field_validator("color", "style_tags", mode="before")
    @classmethod
    def normalize_list(cls, v: list[str] | None) -> list[str]:
        return v if v is not None else []


class BulkInsertError(BaseModel):
    index: int
    detail: str


class CatalogBulkCreateResponse(BaseModel):
    created: int
    failed: int
    items: list[CatalogItemResponse]
    errors: list[BulkInsertError]


# ---------------------------------------------------------------------------
# Image upload flow
# ---------------------------------------------------------------------------

# ALLOWED_CATALOG_CONTENT_TYPES is imported from storage_service so the
# validator and the storage layer always agree on the allowed set.
MAX_CATALOG_FILE_SIZE = 10 * 1024 * 1024  # 10 MB


class CatalogImageUploadRequest(BaseModel):
    brand: str
    filename: str
    content_type: str
    file_size: int

    @field_validator("content_type")
    @classmethod
    def validate_content_type(cls, v: str) -> str:
        if v not in ALLOWED_CATALOG_CONTENT_TYPES:
            raise ValueError(f"Unsupported content type '{v}'. Allowed: {sorted(ALLOWED_CATALOG_CONTENT_TYPES)}")
        return v

    @field_validator("file_size")
    @classmethod
    def validate_file_size(cls, v: int) -> int:
        if v > MAX_CATALOG_FILE_SIZE:
            raise ValueError(f"File size {v} exceeds the 10 MB limit")
        return v


class CatalogImageUploadResponse(BaseModel):
    upload_url: str
    image_url: str
    object_key: str
    expires_in: int


# ---------------------------------------------------------------------------
# Similar items envelope (Task 6)
# ---------------------------------------------------------------------------

class SimilarItemsResponse(BaseModel):
    items: list[SimilarItemResponse]
    total: int
