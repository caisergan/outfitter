from datetime import datetime
from pydantic import BaseModel


class UserResponse(BaseModel):
    id: str
    email: str
    skin_tone: str | None
    created_at: datetime

    model_config = {"from_attributes": True}
