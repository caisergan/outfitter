from __future__ import annotations
import uuid
from sqlalchemy import String, Text, ARRAY
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from pgvector.sqlalchemy import Vector

from app.database import Base
from app.models.base import TimestampMixin


class CatalogItem(Base, TimestampMixin):
    __tablename__ = "catalog_items"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    ref_code: Mapped[str | None] = mapped_column(String(100), nullable=True, unique=True, index=True)
    brand: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    gender: Mapped[str | None] = mapped_column(String(16), nullable=True, index=True)

    # Wardrobe slot — drives outfit composition. 10-value controlled vocab
    # (top/bottom/dress/outerwear/footwear/accessory/bag/underwear/swimwear/activewear).
    slot: Mapped[str] = mapped_column(String(20), nullable=False, index=True)

    # Garment kind (jeans, blazer, t-shirt, polo, ...). ~31-value controlled vocab
    # in scripts.taxonomy_maps.CATEGORIES. Nullable during/after the
    # 0013 → backfill window; the 0014 finalize migration may add NOT NULL
    # where the catalog is fully mapped, but un-mappable source slugs intentionally
    # leave NULL for manual cleanup.
    category: Mapped[str | None] = mapped_column(String(50), nullable=True, index=True)

    # Optional finer-grained subtype within category (oxford, midi, bomber, ...).
    # Sparse — most rows are NULL.
    subcategory: Mapped[str | None] = mapped_column(String(100), nullable=True)

    name: Mapped[str] = mapped_column(String(255), nullable=False)
    color: Mapped[list[str] | None] = mapped_column(ARRAY(String), nullable=True)

    # Pattern is an array (multiple patterns per item: e.g. striped + embroidered).
    # The DB column is `pattern_array` until 0014 drops the legacy scalar
    # `pattern` column and renames pattern_array → pattern. Until then the
    # SQLAlchemy attribute name decouples from the column name.
    pattern: Mapped[list[str] | None] = mapped_column(
        "pattern_array", ARRAY(String), nullable=True,
    )

    fit: Mapped[str | None] = mapped_column(String(50), nullable=True)
    style_tags: Mapped[list[str] | None] = mapped_column(ARRAY(String), nullable=True)
    occasion_tags: Mapped[list[str] | None] = mapped_column(ARRAY(String), nullable=True)

    image_front_url: Mapped[str] = mapped_column(Text, nullable=False)
    image_back_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    product_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    clip_embedding: Mapped[list[float] | None] = mapped_column(Vector(512), nullable=True)
