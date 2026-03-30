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
    category: Mapped[str] = mapped_column(String(50), nullable=False, index=True)
    subtype: Mapped[str | None] = mapped_column(String(100), nullable=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    color: Mapped[list[str] | None] = mapped_column(ARRAY(String), nullable=True)
    pattern: Mapped[str | None] = mapped_column(String(50), nullable=True)
    fit: Mapped[str | None] = mapped_column(String(50), nullable=True)
    style_tags: Mapped[list[str] | None] = mapped_column(ARRAY(String), nullable=True)
    image_url: Mapped[str] = mapped_column(Text, nullable=False)
    product_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    clip_embedding: Mapped[list[float] | None] = mapped_column(Vector(512), nullable=True)
