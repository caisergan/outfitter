from __future__ import annotations
import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text, ARRAY
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from pgvector.sqlalchemy import Vector

from app.database import Base
from app.models.base import TimestampMixin


class WardrobeItem(Base, TimestampMixin):
    __tablename__ = "wardrobe_items"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    category: Mapped[str] = mapped_column(String(50), nullable=False, index=True)
    subtype: Mapped[str | None] = mapped_column(String(100), nullable=True)
    color: Mapped[list[str] | None] = mapped_column(ARRAY(String), nullable=True)
    pattern: Mapped[str | None] = mapped_column(String(50), nullable=True)
    fit: Mapped[str | None] = mapped_column(String(50), nullable=True)
    style_tags: Mapped[list[str] | None] = mapped_column(ARRAY(String), nullable=True)
    image_url: Mapped[str] = mapped_column(Text, nullable=False)
    clip_embedding: Mapped[list[float] | None] = mapped_column(Vector(512), nullable=True)
    times_used: Mapped[int] = mapped_column(Integer, default=0, server_default="0", nullable=False)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
