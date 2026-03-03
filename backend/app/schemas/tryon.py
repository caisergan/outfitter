from typing import Literal
from pydantic import BaseModel


class TryOnSubmitRequest(BaseModel):
    slots: dict
    model_preference: str = "neutral"
    user_photo_url: str | None = None


class TryOnSubmitResponse(BaseModel):
    job_id: str
    status: str = "pending"


class TryOnStatusResponse(BaseModel):
    job_id: str
    status: Literal["pending", "processing", "complete", "failed"]
    image_url: str | None = None
    error: str | None = None
