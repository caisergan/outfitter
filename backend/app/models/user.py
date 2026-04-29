import uuid
from sqlalchemy import String, Text, ForeignKey, ARRAY
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base
from app.models.base import TimestampMixin


class User(Base, TimestampMixin):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    password_hash: Mapped[str] = mapped_column(Text, nullable=False)
    skin_tone: Mapped[str | None] = mapped_column(String(50), nullable=True)


class UserInteraction(Base, TimestampMixin):
    __tablename__ = "user_interactions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    # Etkileşime girilen ürünün (katalog/gardırop) veya kombinin ID'si
    target_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False, index=True)
    target_type: Mapped[str] = mapped_column(String(50), nullable=False)  # 'catalog', 'wardrobe', 'outfit'
    action: Mapped[str] = mapped_column(String(50), nullable=False)  # 'swipe_left', 'swipe_right', 'like', 'view', 'try_on'


class UserProfile(Base, TimestampMixin):
    __tablename__ = "user_profiles"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True, index=True
    )
    preferred_styles: Mapped[list[str] | None] = mapped_column(ARRAY(String), nullable=True)
    disliked_colors: Mapped[list[str] | None] = mapped_column(ARRAY(String), nullable=True)
    body_type: Mapped[str | None] = mapped_column(String(50), nullable=True)
    skin_tone: Mapped[str | None] = mapped_column(String(50), nullable=True)
