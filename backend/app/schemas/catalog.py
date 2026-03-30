import uuid
from datetime import datetime
from pydantic import BaseModel


class CatalogItemCreate(BaseModel):
    brand: str
    category: str
    subtype: str | None = None
    name: str
    color: list[str] | None = None
    pattern: str | None = None
    fit: str | None = None
    style_tags: list[str] | None = None
    image_url: str
    product_url: str | None = None


class CatalogItemUpdate(BaseModel):
    brand: str | None = None
    category: str | None = None
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
    brand: str
    category: str
    subtype: str | None
    name: str
    color: list[str] | None
    pattern: str | None
    fit: str | None
    style_tags: list[str] | None
    image_url: str
    product_url: str | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class CatalogSearchResponse(BaseModel):
    items: list[CatalogItemResponse]
    total: int


class SimilarItemResponse(BaseModel):
    id: uuid.UUID
    name: str
    category: str
    image_url: str
    similarity: float


class BulkInsertError(BaseModel):
    index: int
    detail: str


class CatalogBulkCreateResponse(BaseModel):
    created: int
    failed: int
    items: list[CatalogItemResponse]
    errors: list[BulkInsertError]
