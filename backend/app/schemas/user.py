import uuid
from datetime import datetime
from typing import Literal
from pydantic import BaseModel


class UserResponse(BaseModel):
    id: uuid.UUID
    email: str
    skin_tone: str | None
    role: Literal["user", "admin"] = "user"
    created_at: datetime

    model_config = {"from_attributes": True}
