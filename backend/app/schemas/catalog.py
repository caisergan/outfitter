import uuid
from datetime import datetime
from typing import Literal
from pydantic import BaseModel, field_validator

from app.services.storage_service import ALLOWED_CATALOG_CONTENT_TYPES

# ---------------------------------------------------------------------------
# Controlled vocabularies for the API boundary.
#
# Pydantic needs static Literal types for validation, so the values are
# inlined here. The canonical data still lives in ``scripts.taxonomy_maps``
# — the assertion below detects drift between the two locations at import
# time, so the app fails fast if they diverge.
# ---------------------------------------------------------------------------

CATALOG_SLOT = Literal[
    "top", "bottom", "dress", "outerwear", "footwear",
    "accessory", "bag", "underwear", "swimwear", "activewear",
]

CATALOG_CATEGORY = Literal[
    # tops
    "t-shirt", "polo", "shirt", "blouse", "sweater", "cardigan",
    "sweatshirt", "hoodie", "tank-top",
    # bottoms
    "jeans", "trousers", "shorts", "skirt", "joggers",
    # one-piece
    "dress", "jumpsuit", "bodysuit",
    # outerwear
    "blazer", "jacket", "coat", "trench-coat", "vest",
    # footwear
    "sneakers", "boots", "heels", "sandals",
    # accessories
    "belt", "cap", "bag", "scarf", "sunglasses",
]

CATALOG_PATTERN = Literal[
    "plain", "striped", "checkered", "plaid", "floral", "paisley",
    "polka-dot", "geometric", "animal-print", "abstract", "tie-dye",
    "color-blocked", "embroidered", "sequined", "graphic", "logo",
    "camouflage", "gradient",
]

CATALOG_FIT = Literal[
    "regular", "slim", "skinny", "relaxed", "oversized", "loose",
    "straight", "mom", "wide-leg", "flare", "bootcut", "balloon",
    "baggy", "bodycon", "a-line", "shift", "fit-and-flare",
    "cropped", "tapered",
]

CATALOG_STYLE_TAG = Literal[
    "minimal", "classic", "old-money", "clean-girl", "preppy",
    "streetwear", "bohemian", "romantic", "edgy", "grunge", "vintage",
    "y2k", "sporty", "athleisure", "utility", "glam", "parisian",
]

CATALOG_OCCASION_TAG = Literal[
    "office", "interview", "formal", "wedding-guest", "smart-casual",
    "casual", "date-night", "party", "festival", "travel", "beach",
    "athletic", "loungewear",
]

CATALOG_GENDER = Literal["men", "women"]


def _assert_vocab_in_sync() -> None:
    """Fail fast if the API Literals drift from scripts.taxonomy_maps."""
    try:
        from scripts.taxonomy_maps import (
            SLOTS, CATEGORIES, PATTERNS, FITS, STYLE_TAGS, OCCASION_TAGS,
        )
    except ImportError:
        # scripts/ may not be on sys.path in some tooling contexts. Tests
        # explicitly cross-check; skip silently here.
        return

    pairs = [
        ("CATALOG_SLOT",         CATALOG_SLOT.__args__,         SLOTS),
        ("CATALOG_CATEGORY",     CATALOG_CATEGORY.__args__,     CATEGORIES),
        ("CATALOG_PATTERN",      CATALOG_PATTERN.__args__,      PATTERNS),
        ("CATALOG_FIT",          CATALOG_FIT.__args__,          FITS),
        ("CATALOG_STYLE_TAG",    CATALOG_STYLE_TAG.__args__,    STYLE_TAGS),
        ("CATALOG_OCCASION_TAG", CATALOG_OCCASION_TAG.__args__, OCCASION_TAGS),
    ]
    for name, literal_args, frozen in pairs:
        if frozenset(literal_args) != frozen:
            raise RuntimeError(
                f"app.schemas.catalog.{name} drifted from scripts.taxonomy_maps. "
                f"Schema={frozenset(literal_args)} taxonomy_maps={frozen}."
            )


_assert_vocab_in_sync()


# ---------------------------------------------------------------------------
# Backwards-compatible aliases (REMOVE after Phase 7).
# Some legacy code paths still reference the old names.
# ---------------------------------------------------------------------------
CATALOG_CATEGORIES = CATALOG_SLOT  # legacy: 'category' meant slot in the old shape
CATALOG_GENDERS = CATALOG_GENDER


# ---------------------------------------------------------------------------
# Pydantic models
# ---------------------------------------------------------------------------

class CatalogItemCreate(BaseModel):
    ref_code: str | None = None
    brand: str
    gender: CATALOG_GENDER | None = None
    slot: CATALOG_SLOT
    category: CATALOG_CATEGORY | None = None
    subcategory: str | None = None
    name: str
    color: list[str] | None = None
    pattern: list[CATALOG_PATTERN] | None = None
    fit: CATALOG_FIT | None = None
    style_tags: list[CATALOG_STYLE_TAG] | None = None
    occasion_tags: list[CATALOG_OCCASION_TAG] | None = None
    image_front_url: str
    image_back_url: str | None = None
    product_url: str | None = None


class CatalogItemUpdate(BaseModel):
    ref_code: str | None = None
    brand: str | None = None
    gender: CATALOG_GENDER | None = None
    slot: CATALOG_SLOT | None = None
    category: CATALOG_CATEGORY | None = None
    subcategory: str | None = None
    name: str | None = None
    color: list[str] | None = None
    pattern: list[CATALOG_PATTERN] | None = None
    fit: CATALOG_FIT | None = None
    style_tags: list[CATALOG_STYLE_TAG] | None = None
    occasion_tags: list[CATALOG_OCCASION_TAG] | None = None
    image_front_url: str | None = None
    image_back_url: str | None = None
    product_url: str | None = None


class CatalogItemResponse(BaseModel):
    id: uuid.UUID
    ref_code: str | None
    brand: str
    gender: str | None
    slot: str
    category: str | None
    subcategory: str | None
    name: str
    color: list[str]
    pattern: list[str]
    fit: str | None
    style_tags: list[str]
    occasion_tags: list[str]
    image_front_url: str
    image_back_url: str | None
    product_url: str | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}

    @field_validator("color", "pattern", "style_tags", "occasion_tags", mode="before")
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
    slot: str
    category: str | None
    color: list[str]
    style_tags: list[str]
    occasion_tags: list[str]
    image_front_url: str
    similarity: float

    @field_validator("color", "style_tags", "occasion_tags", mode="before")
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
# Similar items envelope
# ---------------------------------------------------------------------------

class SimilarItemsResponse(BaseModel):
    items: list[SimilarItemResponse]
    total: int
