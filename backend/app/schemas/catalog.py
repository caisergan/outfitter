from datetime import datetime
from pydantic import BaseModel


class CatalogItemResponse(BaseModel):
    id: str
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

    model_config = {"from_attributes": True}


class CatalogSearchResponse(BaseModel):
    items: list[CatalogItemResponse]
    total: int


class SimilarItemResponse(BaseModel):
    id: str
    name: str
    category: str
    image_url: str
    similarity: float
