import uuid
from datetime import datetime
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

PlaygroundSize = Literal["1024x1024", "1024x1536", "1536x1024"]
PlaygroundQuality = Literal["low", "medium", "high"]
GenderLiteral = Literal["female", "male"]
StatusLiteral = Literal["success", "failed"]

# The hard cap the proxy accepts. Combined-length validation uses this.
PROMPT_CHAR_CAP = 32000


class GenerateRequest(BaseModel):
    catalog_item_ids: Annotated[list[uuid.UUID], Field(min_length=1, max_length=16)]
    system_prompt: Annotated[str, Field(min_length=1, max_length=PROMPT_CHAR_CAP)]
    user_prompt: Annotated[str, Field(max_length=PROMPT_CHAR_CAP)] = ""
    template_id: uuid.UUID | None = None
    persona_id: uuid.UUID | None = None
    size: PlaygroundSize = "1024x1536"
    quality: PlaygroundQuality = "high"
    n: Annotated[int, Field(ge=1, le=4)] = 1

    @model_validator(mode="after")
    def _check_combined_length(self) -> "GenerateRequest":
        sp = (self.system_prompt or "").strip()
        up = (self.user_prompt or "").strip()
        sep = "\n\n" if sp and up else ""
        if len(sp) + len(sep) + len(up) > PROMPT_CHAR_CAP:
            raise ValueError(
                f"Combined prompt length exceeds {PROMPT_CHAR_CAP} characters"
            )
        return self


class GenerateResponse(BaseModel):
    run_id: uuid.UUID
    images: list[str]
    model: str
    item_count: int
    elapsed_ms: int
    daily_used: int
    daily_limit: int


SLUG_PATTERN = r"^[a-z0-9_]+$"


class SystemPromptOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    slug: str
    label: str
    content: str
    is_active: bool


class SystemPromptUpdate(BaseModel):
    content: Annotated[str, Field(min_length=1, max_length=PROMPT_CHAR_CAP)] | None = None
    label: Annotated[str, Field(min_length=1, max_length=128)] | None = None


class TemplateOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    slug: str
    label: str
    description: str | None = None
    body: str
    is_active: bool


class TemplateCreate(BaseModel):
    slug: Annotated[str, Field(min_length=1, max_length=64, pattern=SLUG_PATTERN)]
    label: Annotated[str, Field(min_length=1, max_length=128)]
    description: str | None = None
    body: Annotated[str, Field(min_length=1)]


class TemplateUpdate(BaseModel):
    label: Annotated[str, Field(min_length=1, max_length=128)] | None = None
    description: str | None = None
    body: Annotated[str, Field(min_length=1)] | None = None
    is_active: bool | None = None


class PersonaOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    slug: str
    label: str
    gender: GenderLiteral
    description: str
    is_active: bool


class PersonaCreate(BaseModel):
    slug: Annotated[str, Field(min_length=1, max_length=64, pattern=SLUG_PATTERN)]
    label: Annotated[str, Field(min_length=1, max_length=128)]
    gender: GenderLiteral
    description: Annotated[str, Field(min_length=1)]


class PersonaUpdate(BaseModel):
    """Update schema for personas. Gender is intentionally immutable post-create."""

    label: Annotated[str, Field(min_length=1, max_length=128)] | None = None
    description: Annotated[str, Field(min_length=1)] | None = None
    is_active: bool | None = None


class RunOut(BaseModel):
    """Snapshot of a persisted playground run.

    `image_keys` are the R2 object keys; `images` are short-lived presigned
    GET URLs computed at serialization time by the router.
    """

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    catalog_item_ids: list[uuid.UUID]
    system_prompt_id: uuid.UUID | None
    template_id: uuid.UUID | None
    persona_id: uuid.UUID | None
    system_prompt_text: str
    user_prompt_text: str
    final_prompt_text: str
    size: str
    quality: str
    n: int
    image_keys: list[str]
    images: list[str]
    model_name: str
    elapsed_ms: int
    status: StatusLiteral
    error_message: str | None
    created_at: datetime


class RunListOut(BaseModel):
    items: list[RunOut]
    next_cursor: str | None = None
