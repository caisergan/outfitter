from __future__ import annotations
import uuid
from sqlalchemy import CheckConstraint, ForeignKey, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base
from app.models.base import TimestampMixin


class SavedOutfit(Base, TimestampMixin):
    __tablename__ = "saved_outfits"
    __table_args__ = (
        CheckConstraint("source IN ('playground', 'assistant')", name="ck_saved_outfits_source"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    source: Mapped[str] = mapped_column(String(20), nullable=False)
    slots: Mapped[dict] = mapped_column(JSONB, nullable=False)
    generated_image_url: Mapped[str | None] = mapped_column(Text, nullable=True)
