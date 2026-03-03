from sqlalchemy import CheckConstraint, ForeignKey, String, Text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base
from app.models.base import generate_uuid

from datetime import datetime
from sqlalchemy import DateTime, func


class SavedOutfit(Base):
    __tablename__ = "saved_outfits"
    __table_args__ = (
        CheckConstraint("source IN ('playground', 'assistant')", name="ck_saved_outfits_source"),
    )

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=generate_uuid
    )
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    source: Mapped[str] = mapped_column(String(20), nullable=False)
    slots: Mapped[dict] = mapped_column(JSONB, nullable=False)
    generated_image_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
