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
    updated_at: datetime

    model_config = {"from_attributes": True}

    @classmethod
    def model_validate(cls, obj, **kwargs):
        # Coerce UUID pk to str
        if hasattr(obj, "id") and not isinstance(obj.id, str):
            obj.id = str(obj.id)
        return super().model_validate(obj, **kwargs)


class CatalogSearchResponse(BaseModel):
    items: list[CatalogItemResponse]
    total: int


class SimilarItemResponse(BaseModel):
    id: str
    name: str
    category: str
    image_url: str
    similarity: float
