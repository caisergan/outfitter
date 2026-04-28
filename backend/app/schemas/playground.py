import uuid
from typing import Annotated, Literal

from pydantic import BaseModel, Field

PlaygroundSize = Literal["1024x1024", "1024x1536", "1536x1024"]
PlaygroundQuality = Literal["low", "medium", "high"]


class PlaygroundGenerateRequest(BaseModel):
    catalog_item_ids: Annotated[list[uuid.UUID], Field(min_length=1, max_length=16)]
    prompt: Annotated[str, Field(min_length=1, max_length=32000)]
    size: PlaygroundSize = "1024x1536"
    quality: PlaygroundQuality = "high"
    n: Annotated[int, Field(ge=1, le=4)] = 1


class PlaygroundGenerateResponse(BaseModel):
    images: list[str]   # data URLs ("data:image/png;base64,...")
    model: str
    item_count: int
    elapsed_ms: int
