import base64
import logging
import time
import uuid
from datetime import datetime, timedelta, timezone
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.jwt import get_current_user
from app.config import settings
from app.database import get_db
from app.models.catalog import CatalogItem
from app.models.playground import (
    ModelPersona,
    PlaygroundRun,
    SystemPrompt,
    UserPromptTemplate,
)
from app.models.user import User
from app.schemas.playground import (
    GenerateRequest,
    GenerateResponse,
    PersonaOut,
    RunListOut,
    RunOut,
    SystemPromptOut,
    TemplateOut,
)
from app.services import storage_service
from app.services.codex_image_service import (
    CodexProxyError,
    CodexProxyTimeout,
    ReferenceImageError,
    generate_outfit_image_bytes,
)
from app.services.storage_service import StorageError

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/playground", tags=["playground"])

DbDep = Annotated[AsyncSession, Depends(get_db)]
CurrentUserDep = Annotated[User, Depends(get_current_user)]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _utc_midnight_today() -> datetime:
    return datetime.now(timezone.utc).replace(
        hour=0, minute=0, second=0, microsecond=0
    )


def _build_final_prompt(system_prompt: str, user_prompt: str) -> str:
    """Mirrors editorial.js buildFinalPrompt — strip each piece, drop empties, join with blank line."""
    parts = [s.strip() for s in (system_prompt, user_prompt)]
    parts = [p for p in parts if p]
    return "\n\n".join(parts)


def _encode_cursor(created_at: datetime, run_id: uuid.UUID) -> str:
    raw = f"{created_at.isoformat()}|{run_id}".encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("ascii")


def _decode_cursor(cursor: str) -> tuple[datetime, uuid.UUID]:
    try:
        raw = base64.urlsafe_b64decode(cursor.encode("ascii")).decode("utf-8")
        ts_str, rid_str = raw.split("|", 1)
        return datetime.fromisoformat(ts_str), uuid.UUID(rid_str)
    except (ValueError, UnicodeDecodeError) as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid cursor"
        ) from exc


def _serialize_run(row: PlaygroundRun) -> RunOut:
    keys = list(row.image_keys or [])
    images = [storage_service.get_signed_read_url(k) for k in keys]
    return RunOut(
        id=row.id,
        catalog_item_ids=[uuid.UUID(str(x)) for x in (row.catalog_item_ids or [])],
        system_prompt_id=row.system_prompt_id,
        template_id=row.template_id,
        persona_id=row.persona_id,
        system_prompt_text=row.system_prompt_text,
        user_prompt_text=row.user_prompt_text,
        final_prompt_text=row.final_prompt_text,
        size=row.size,
        quality=row.quality,
        n=row.n,
        image_keys=keys,
        images=images,
        model_name=row.model_name,
        elapsed_ms=row.elapsed_ms,
        status=row.status,
        error_message=row.error_message,
        created_at=row.created_at,
    )


async def _count_today(db: AsyncSession, user_id: uuid.UUID) -> int:
    midnight = _utc_midnight_today()
    q = select(func.count(PlaygroundRun.id)).where(
        PlaygroundRun.user_id == user_id,
        PlaygroundRun.created_at >= midnight,
        PlaygroundRun.deleted_at.is_(None),
    )
    if not settings.PLAYGROUND_FAILED_RUNS_COUNT_TOWARD_CAP:
        q = q.where(PlaygroundRun.status == "success")
    return (await db.execute(q)).scalar_one()


def _map_codex_error(exc: Exception) -> HTTPException:
    if isinstance(exc, CodexProxyTimeout):
        return HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail="Image generation timed out",
        )
    if isinstance(exc, CodexProxyError):
        return HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Image generation failed: {exc}",
        )
    if isinstance(exc, ReferenceImageError):
        return HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Failed to fetch reference image: {exc}",
        )
    return HTTPException(
        status_code=status.HTTP_502_BAD_GATEWAY,
        detail="Image generation failed",
    )


async def _persist_run(
    db: AsyncSession,
    *,
    run_id: uuid.UUID,
    user_id: uuid.UUID,
    body: GenerateRequest,
    system_prompt_id: uuid.UUID | None,
    template_id: uuid.UUID | None,
    persona_id: uuid.UUID | None,
    final_prompt: str,
    elapsed_ms: int,
    image_keys: list[str],
    status_value: str,
    error_message: str | None,
) -> PlaygroundRun:
    run = PlaygroundRun(
        id=run_id,
        user_id=user_id,
        # Stringify UUIDs so the row works on both Postgres ARRAY(UUID) and the
        # SQLite ARRAY→JSON shim used in tests.
        catalog_item_ids=[str(i) for i in body.catalog_item_ids],
        system_prompt_id=system_prompt_id,
        template_id=template_id,
        persona_id=persona_id,
        system_prompt_text=body.system_prompt,
        user_prompt_text=body.user_prompt,
        final_prompt_text=final_prompt,
        size=body.size,
        quality=body.quality,
        n=body.n,
        image_keys=list(image_keys),
        model_name="gpt-image-2",
        elapsed_ms=elapsed_ms,
        status=status_value,
        error_message=error_message,
    )
    db.add(run)
    await db.commit()
    await db.refresh(run)
    return run


# ---------------------------------------------------------------------------
# Read endpoints
# ---------------------------------------------------------------------------


@router.get("/system-prompt", response_model=SystemPromptOut)
async def get_active_system_prompt(
    db: DbDep,
    _: CurrentUserDep,
) -> SystemPromptOut:
    row = (
        await db.execute(
            select(SystemPrompt)
            .where(SystemPrompt.is_active.is_(True))
            .order_by(SystemPrompt.created_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No active system prompt configured",
        )
    return SystemPromptOut.model_validate(row)


@router.get("/templates", response_model=list[TemplateOut])
async def list_templates(
    db: DbDep,
    _: CurrentUserDep,
) -> list[TemplateOut]:
    rows = (
        (
            await db.execute(
                select(UserPromptTemplate)
                .where(UserPromptTemplate.is_active.is_(True))
                .order_by(UserPromptTemplate.label)
            )
        )
        .scalars()
        .all()
    )
    return [TemplateOut.model_validate(r) for r in rows]


@router.get("/personas", response_model=list[PersonaOut])
async def list_personas(
    db: DbDep,
    _: CurrentUserDep,
    gender: Annotated[Literal["female", "male"] | None, Query()] = None,
) -> list[PersonaOut]:
    q = select(ModelPersona).where(ModelPersona.is_active.is_(True))
    if gender is not None:
        q = q.where(ModelPersona.gender == gender)
    rows = (
        (await db.execute(q.order_by(ModelPersona.gender, ModelPersona.label)))
        .scalars()
        .all()
    )
    return [PersonaOut.model_validate(r) for r in rows]


# ---------------------------------------------------------------------------
# Write endpoint
# ---------------------------------------------------------------------------


@router.post("/generate-image", response_model=GenerateResponse)
async def generate_image(
    body: GenerateRequest,
    db: DbDep,
    current_user: CurrentUserDep,
) -> GenerateResponse:
    # 1. Daily cap
    used = await _count_today(db, current_user.id)
    if used >= settings.PLAYGROUND_DAILY_CAP:
        midnight = _utc_midnight_today()
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail={
                "ok": False,
                "error": {
                    "code": "DAILY_LIMIT_REACHED",
                    "limit": settings.PLAYGROUND_DAILY_CAP,
                    "used": used,
                    "reset_at": (midnight + timedelta(days=1)).isoformat(),
                },
            },
        )

    # 2. Validate optional FKs (404 if not found or inactive)
    template = None
    persona = None
    if body.template_id is not None:
        template = (
            await db.execute(
                select(UserPromptTemplate).where(
                    UserPromptTemplate.id == body.template_id,
                    UserPromptTemplate.is_active.is_(True),
                )
            )
        ).scalar_one_or_none()
        if template is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Template {body.template_id} not found",
            )
    if body.persona_id is not None:
        persona = (
            await db.execute(
                select(ModelPersona).where(
                    ModelPersona.id == body.persona_id,
                    ModelPersona.is_active.is_(True),
                )
            )
        ).scalar_one_or_none()
        if persona is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Persona {body.persona_id} not found",
            )

    # 3. Snapshot active system prompt id (audit FK only — text is in the request body)
    sp_row = (
        await db.execute(
            select(SystemPrompt)
            .where(SystemPrompt.is_active.is_(True))
            .order_by(SystemPrompt.created_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()
    system_prompt_id = sp_row.id if sp_row else None

    # 4. Fetch catalog items, build reference URL list (preserving caller order)
    ids = list(body.catalog_item_ids)
    items = (
        (await db.execute(select(CatalogItem).where(CatalogItem.id.in_(ids))))
        .scalars()
        .all()
    )
    found = {item.id: item for item in items}
    missing = [i for i in ids if i not in found]
    if missing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Catalog item {missing[0]} not found",
        )
    reference_urls = [found[i].image_front_url for i in ids]

    # 5. Build the final prompt that gpt-image-2 sees
    final_prompt = _build_final_prompt(body.system_prompt, body.user_prompt)

    # 6. Call gpt-image-2; on failure persist a failed-run snapshot then map to HTTP error
    run_id = uuid.uuid4()
    template_id = template.id if template else None
    persona_id = persona.id if persona else None
    started = time.perf_counter()
    try:
        images_bytes = await generate_outfit_image_bytes(
            reference_urls=reference_urls,
            prompt=final_prompt,
            size=body.size,
            quality=body.quality,
            n=body.n,
        )
    except (CodexProxyTimeout, CodexProxyError, ReferenceImageError) as exc:
        elapsed_ms = int((time.perf_counter() - started) * 1000)
        await _persist_run(
            db,
            run_id=run_id,
            user_id=current_user.id,
            body=body,
            system_prompt_id=system_prompt_id,
            template_id=template_id,
            persona_id=persona_id,
            final_prompt=final_prompt,
            elapsed_ms=elapsed_ms,
            image_keys=[],
            status_value="failed",
            error_message=str(exc),
        )
        raise _map_codex_error(exc) from exc

    elapsed_ms = int((time.perf_counter() - started) * 1000)

    # 7. Upload generated images to R2; on failure persist a failed-run snapshot then 502
    image_keys: list[str] = []
    try:
        for idx, data in enumerate(images_bytes):
            key = f"playground/{current_user.id}/{run_id}/{idx}.png"
            storage_service.upload_bytes(key, data, "image/png")
            image_keys.append(key)
    except StorageError as exc:
        await _persist_run(
            db,
            run_id=run_id,
            user_id=current_user.id,
            body=body,
            system_prompt_id=system_prompt_id,
            template_id=template_id,
            persona_id=persona_id,
            final_prompt=final_prompt,
            elapsed_ms=elapsed_ms,
            image_keys=image_keys,
            status_value="failed",
            error_message=str(exc),
        )
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Storage upload failed: {exc}",
        ) from exc

    # 8. Persist success snapshot
    await _persist_run(
        db,
        run_id=run_id,
        user_id=current_user.id,
        body=body,
        system_prompt_id=system_prompt_id,
        template_id=template_id,
        persona_id=persona_id,
        final_prompt=final_prompt,
        elapsed_ms=elapsed_ms,
        image_keys=image_keys,
        status_value="success",
        error_message=None,
    )

    # 9. Build presigned URLs for the response
    presigned = [storage_service.get_signed_read_url(k) for k in image_keys]
    return GenerateResponse(
        run_id=run_id,
        images=presigned,
        model="gpt-image-2",
        item_count=len(ids),
        elapsed_ms=elapsed_ms,
        daily_used=used + 1,
        daily_limit=settings.PLAYGROUND_DAILY_CAP,
    )


# ---------------------------------------------------------------------------
# History endpoints
# ---------------------------------------------------------------------------


@router.get("/runs", response_model=RunListOut)
async def list_runs(
    db: DbDep,
    current_user: CurrentUserDep,
    limit: Annotated[int, Query(ge=1, le=50)] = 20,
    cursor: Annotated[str | None, Query()] = None,
) -> RunListOut:
    q = (
        select(PlaygroundRun)
        .where(
            PlaygroundRun.user_id == current_user.id,
            PlaygroundRun.deleted_at.is_(None),
        )
        .order_by(PlaygroundRun.created_at.desc(), PlaygroundRun.id.desc())
    )
    if cursor:
        ts, rid = _decode_cursor(cursor)
        q = q.where(
            or_(
                PlaygroundRun.created_at < ts,
                and_(
                    PlaygroundRun.created_at == ts,
                    PlaygroundRun.id < rid,
                ),
            )
        )
    rows = (await db.execute(q.limit(limit + 1))).scalars().all()
    has_more = len(rows) > limit
    page = list(rows[:limit])
    next_cursor = (
        _encode_cursor(page[-1].created_at, page[-1].id) if has_more else None
    )
    return RunListOut(
        items=[_serialize_run(r) for r in page],
        next_cursor=next_cursor,
    )


@router.get("/runs/{run_id}", response_model=RunOut)
async def get_run(
    run_id: uuid.UUID,
    db: DbDep,
    current_user: CurrentUserDep,
) -> RunOut:
    row = (
        await db.execute(
            select(PlaygroundRun).where(
                PlaygroundRun.id == run_id,
                PlaygroundRun.user_id == current_user.id,
                PlaygroundRun.deleted_at.is_(None),
            )
        )
    ).scalar_one_or_none()
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Run not found",
        )
    return _serialize_run(row)
