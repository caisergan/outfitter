from datetime import datetime
from pydantic import BaseModel


class UserResponse(BaseModel):
    id: str
    email: str
    skin_tone: str | None
    created_at: datetime

    model_config = {"from_attributes": True}

    @classmethod
    def model_validate(cls, obj, **kwargs):
        # Coerce UUID pk to str for JSON serialisation
        if hasattr(obj, "id") and not isinstance(obj.id, str):
            obj.id = str(obj.id)
        return super().model_validate(obj, **kwargs)
