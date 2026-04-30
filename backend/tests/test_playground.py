import asyncio
import uuid
from datetime import datetime, timedelta, timezone

import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.models.catalog import CatalogItem
from app.models.playground import (
    ModelPersona,
    PlaygroundRun,
    SystemPrompt,
    UserPromptTemplate,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


async def _signup(
    client: AsyncClient, email: str = "playground@outfitter.dev"
):
    return await client.post(
        "/auth/signup", json={"email": email, "password": "supersecret99"}
    )


async def _signup_admin(
    client: AsyncClient, db, email: str = "admin@outfitter.dev"
) -> str:
    """Create a user and promote them to admin via direct DB update.

    Returns the access token.
    """
    from app.models.user import User

    resp = await client.post(
        "/auth/signup", json={"email": email, "password": "supersecret99"}
    )
    token = resp.json()["access_token"]
    user = (
        await db.execute(select(User).where(User.email == email))
    ).scalar_one()
    user.role = "admin"
    await db.commit()
    return token


async def _seed_item(db, **overrides) -> CatalogItem:
    defaults = dict(
        brand="Mango",
        gender="women",
        category="top",
        name="Test Tee",
        color=["black"],
        style_tags=["casual"],
        image_front_url="https://cdn.example.com/test-tee.jpg",
    )
    defaults.update(overrides)
    item = CatalogItem(**defaults)
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item


async def _seed_system_prompt(
    db,
    *,
    slug: str = "global",
    label: str = "Global",
    content: str = "SEEDED SYSTEM PROMPT",
    is_active: bool = True,
) -> SystemPrompt:
    row = SystemPrompt(slug=slug, label=label, content=content, is_active=is_active)
    db.add(row)
    await db.commit()
    await db.refresh(row)
    return row


async def _seed_template(
    db,
    *,
    slug: str = "tpl",
    label: str = "Template",
    description: str | None = None,
    body: str = "Render {{MODEL}} in some vibe.",
    is_active: bool = True,
) -> UserPromptTemplate:
    row = UserPromptTemplate(
        slug=slug,
        label=label,
        description=description,
        body=body,
        is_active=is_active,
    )
    db.add(row)
    await db.commit()
    await db.refresh(row)
    return row


async def _seed_persona(
    db,
    *,
    slug: str = "p1",
    label: str = "Persona",
    gender: str = "female",
    description: str = "- some description",
    is_active: bool = True,
) -> ModelPersona:
    row = ModelPersona(
        slug=slug,
        label=label,
        gender=gender,
        description=description,
        is_active=is_active,
    )
    db.add(row)
    await db.commit()
    await db.refresh(row)
    return row


def _install_fakes(
    monkeypatch,
    db,
    *,
    images: list[bytes] | None = None,
    codex_raises: Exception | None = None,
    storage_raises_on_index: int | None = None,
):
    """Wire test fakes for the async generation flow.

    POST /generate-image now persists a `pending` row and fires
    `_finish_generation` via asyncio.create_task. The real
    `_finish_generation` would call codex + upload via AsyncSessionLocal,
    which doesn't work in the SQLite test setup AND running concurrently
    with the test's own session causes async-session transaction races.

    Instead this helper:
    - Neutralizes the real bg task by replacing `_finish_generation` with
      a no-op coroutine.
    - Records what the simulated bg work *would* have done (success vs
      failed via codex/storage params) so a follow-up call to
      ``_simulate_finish`` writes the eventual state to the test session
      synchronously, without any concurrency.

    Also installs a fake signed-read so RunOut.images comes out as stable
    `https://signed/<key>` strings.
    """
    from app.services.storage_service import StorageError

    image_payload = images if images is not None else [b"fake"]

    async def fake_finish(*, run_id, **_kwargs):  # noqa: ARG001
        # Real bg task is replaced with a no-op; the test drives the
        # eventual row state via _simulate_finish below.
        return None

    def fake_signed_read(key: str, expires_in: int = 900) -> str:
        return f"https://signed/{key}"

    monkeypatch.setattr(
        "app.routers.playground._finish_generation", fake_finish
    )
    monkeypatch.setattr(
        "app.routers.playground.storage_service.get_signed_read_url",
        fake_signed_read,
    )

    # Stash the simulation parameters on the db session for later retrieval
    # by _simulate_finish. Avoids passing them around through every test.
    db.info["_fake_image_payload"] = image_payload
    db.info["_fake_codex_raises"] = codex_raises
    db.info["_fake_storage_raises_on_index"] = storage_raises_on_index
    db.info["_fake_storage_error_cls"] = StorageError


async def _simulate_finish(db, run_id):
    """Drive the in-test simulation of the background generation, writing
    the eventual `success` or `failed` state to the run row using the
    same test session that the request handler used. Mirrors the real
    `_finish_generation` logic but stays single-threaded so SQLite
    AsyncSession can handle it cleanly.
    """
    image_payload = db.info["_fake_image_payload"]
    codex_raises = db.info["_fake_codex_raises"]
    storage_raises_on_index = db.info["_fake_storage_raises_on_index"]
    storage_error_cls = db.info["_fake_storage_error_cls"]

    row = (
        await db.execute(select(PlaygroundRun).where(PlaygroundRun.id == run_id))
    ).scalar_one_or_none()
    if row is None:
        return

    if codex_raises is not None:
        row.status = "failed"
        row.image_keys = []
        row.elapsed_ms = 42
        row.error_message = str(codex_raises)
        await db.commit()
        return

    image_keys: list[str] = []
    try:
        for idx in range(len(image_payload)):
            if (
                storage_raises_on_index is not None
                and idx == storage_raises_on_index
            ):
                raise storage_error_cls("simulated R2 failure")
            image_keys.append(f"playground/{row.user_id}/{run_id}/{idx}.png")
    except Exception as exc:
        row.status = "failed"
        row.image_keys = list(image_keys)
        row.elapsed_ms = 42
        row.error_message = f"Storage upload failed: {exc}"
        await db.commit()
        return

    row.status = "success"
    row.image_keys = image_keys
    row.elapsed_ms = 42
    row.error_message = None
    await db.commit()


async def _await_run_finish(client, db, token, run_id):
    """Drive the fake bg task and re-fetch the run via the API.

    Returns the parsed JSON of GET /playground/runs/{run_id}.
    """
    await _simulate_finish(db, run_id)
    resp = await client.get(
        f"/playground/runs/{run_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    return resp.json()


def _auth_headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _generate_body(
    item_id, *, system_prompt: str = "SYS", user_prompt: str = "", **overrides
) -> dict:
    body = {
        "catalog_item_ids": [str(item_id)],
        "system_prompt": system_prompt,
        "user_prompt": user_prompt,
        "size": "1024x1536",
        "quality": "high",
        "n": 1,
    }
    body.update(overrides)
    return body


# ---------------------------------------------------------------------------
# Generate endpoint — happy path & validation
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_playground_generate_happy_path(
    client: AsyncClient, db, monkeypatch
):
    signup_resp = await _signup(client)
    token = signup_resp.json()["access_token"]
    item = await _seed_item(db)
    _install_fakes(monkeypatch, db)

    response = await client.post(
        "/playground/generate-image",
        headers=_auth_headers(token),
        json=_generate_body(
            item.id, system_prompt="THE SYSTEM PROMPT", user_prompt="THE USER NOTES"
        ),
    )

    # Initial response: 202 Accepted with a pending placeholder
    assert response.status_code == 202, response.text
    body = response.json()
    assert body["status"] == "pending"
    assert body["images"] == []
    assert body["elapsed_ms"] == 0
    assert body["model"] == "gpt-image-2"
    assert body["item_count"] == 1
    assert body["daily_used"] == 1
    assert body["daily_limit"] == 5

    run_id = body["run_id"]
    final = await _await_run_finish(client, db, token, run_id)
    assert final["status"] == "success"
    assert len(final["images"]) == 1
    assert final["images"][0].startswith("https://signed/playground/")
    assert final["images"][0].endswith(f"/{run_id}/0.png")

    # Snapshot fields persisted on the row in their final form
    runs = (await db.execute(select(PlaygroundRun))).scalars().all()
    assert len(runs) == 1
    run = runs[0]
    assert run.status == "success"
    assert run.system_prompt_text == "THE SYSTEM PROMPT"
    assert run.user_prompt_text == "THE USER NOTES"
    assert run.final_prompt_text == "THE SYSTEM PROMPT\n\nTHE USER NOTES"
    assert run.image_keys[0].endswith("/0.png")
    assert run.model_name == "gpt-image-2"


@pytest.mark.asyncio
async def test_playground_unauthorized(client: AsyncClient):
    response = await client.post(
        "/playground/generate-image",
        json={
            "catalog_item_ids": [str(uuid.uuid4())],
            "system_prompt": "x",
            "user_prompt": "",
        },
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_playground_unknown_item_id(
    client: AsyncClient, db, monkeypatch
):
    signup_resp = await _signup(client, email="unknown@outfitter.dev")
    token = signup_resp.json()["access_token"]
    bogus = uuid.uuid4()
    _install_fakes(monkeypatch, db)

    response = await client.post(
        "/playground/generate-image",
        headers=_auth_headers(token),
        json=_generate_body(bogus),
    )
    assert response.status_code == 404
    assert str(bogus) in response.json()["detail"]


@pytest.mark.asyncio
async def test_playground_validation_empty_system_prompt(
    client: AsyncClient, db
):
    signup_resp = await _signup(client, email="empty@outfitter.dev")
    token = signup_resp.json()["access_token"]
    item = await _seed_item(db)

    response = await client.post(
        "/playground/generate-image",
        headers=_auth_headers(token),
        json={
            "catalog_item_ids": [str(item.id)],
            "system_prompt": "",
            "user_prompt": "anything",
        },
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_playground_validation_no_items(client: AsyncClient, db):
    signup_resp = await _signup(client, email="noitems@outfitter.dev")
    token = signup_resp.json()["access_token"]

    response = await client.post(
        "/playground/generate-image",
        headers=_auth_headers(token),
        json={"catalog_item_ids": [], "system_prompt": "x"},
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_playground_validation_too_many_items(
    client: AsyncClient, db
):
    signup_resp = await _signup(client, email="toomany@outfitter.dev")
    token = signup_resp.json()["access_token"]

    response = await client.post(
        "/playground/generate-image",
        headers=_auth_headers(token),
        json={
            "catalog_item_ids": [str(uuid.uuid4()) for _ in range(17)],
            "system_prompt": "x",
        },
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_playground_validation_combined_length(
    client: AsyncClient, db
):
    signup_resp = await _signup(client, email="long@outfitter.dev")
    token = signup_resp.json()["access_token"]
    item = await _seed_item(db)

    response = await client.post(
        "/playground/generate-image",
        headers=_auth_headers(token),
        json={
            "catalog_item_ids": [str(item.id)],
            "system_prompt": "a" * 30000,
            "user_prompt": "b" * 5000,
        },
    )
    assert response.status_code == 422
    assert "Combined prompt length" in response.text


# ---------------------------------------------------------------------------
# Generate endpoint — failure paths
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_playground_proxy_error_writes_failed_row(
    client: AsyncClient, db, monkeypatch
):
    """Codex proxy errors no longer 502 the user — they happen in the
    background task and surface as a `failed` row that the client polls."""
    from app.services.codex_image_service import CodexProxyError

    signup_resp = await _signup(client, email="proxyerr@outfitter.dev")
    token = signup_resp.json()["access_token"]
    item = await _seed_item(db)
    _install_fakes(monkeypatch, db, codex_raises=CodexProxyError("500: upstream blew up"))

    response = await client.post(
        "/playground/generate-image",
        headers=_auth_headers(token),
        json=_generate_body(item.id),
    )
    assert response.status_code == 202
    run_id = response.json()["run_id"]

    final = await _await_run_finish(client, db, token, run_id)
    assert final["status"] == "failed"
    assert "upstream blew up" in (final["error_message"] or "")
    assert final["image_keys"] == []


@pytest.mark.asyncio
async def test_playground_timeout_writes_failed_row(
    client: AsyncClient, db, monkeypatch
):
    from app.services.codex_image_service import CodexProxyTimeout

    signup_resp = await _signup(client, email="timeout@outfitter.dev")
    token = signup_resp.json()["access_token"]
    item = await _seed_item(db)
    _install_fakes(monkeypatch, db, codex_raises=CodexProxyTimeout("read timeout"))

    response = await client.post(
        "/playground/generate-image",
        headers=_auth_headers(token),
        json=_generate_body(item.id),
    )
    assert response.status_code == 202
    run_id = response.json()["run_id"]

    final = await _await_run_finish(client, db, token, run_id)
    assert final["status"] == "failed"
    assert "read timeout" in (final["error_message"] or "")


@pytest.mark.asyncio
async def test_playground_storage_failure_writes_failed_row(
    client: AsyncClient, db, monkeypatch
):
    signup_resp = await _signup(client, email="storage@outfitter.dev")
    token = signup_resp.json()["access_token"]
    item = await _seed_item(db)
    _install_fakes(monkeypatch, db, storage_raises_on_index=0)

    response = await client.post(
        "/playground/generate-image",
        headers=_auth_headers(token),
        json=_generate_body(item.id),
    )
    assert response.status_code == 202
    run_id = response.json()["run_id"]

    final = await _await_run_finish(client, db, token, run_id)
    assert final["status"] == "failed"
    assert "simulated R2 failure" in (final["error_message"] or "")


# ---------------------------------------------------------------------------
# Optional FK validation
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_playground_invalid_template_id_404(
    client: AsyncClient, db, monkeypatch
):
    signup_resp = await _signup(client, email="badtpl@outfitter.dev")
    token = signup_resp.json()["access_token"]
    item = await _seed_item(db)
    _install_fakes(monkeypatch, db)
    bogus = uuid.uuid4()

    body = _generate_body(item.id)
    body["template_id"] = str(bogus)

    response = await client.post(
        "/playground/generate-image",
        headers=_auth_headers(token),
        json=body,
    )
    assert response.status_code == 404
    assert "Template" in response.json()["detail"]


@pytest.mark.asyncio
async def test_playground_invalid_persona_id_404(
    client: AsyncClient, db, monkeypatch
):
    signup_resp = await _signup(client, email="badpers@outfitter.dev")
    token = signup_resp.json()["access_token"]
    item = await _seed_item(db)
    _install_fakes(monkeypatch, db)
    bogus = uuid.uuid4()

    body = _generate_body(item.id)
    body["persona_id"] = str(bogus)

    response = await client.post(
        "/playground/generate-image",
        headers=_auth_headers(token),
        json=body,
    )
    assert response.status_code == 404
    assert "Persona" in response.json()["detail"]


@pytest.mark.asyncio
async def test_playground_inactive_template_404(
    client: AsyncClient, db, monkeypatch
):
    signup_resp = await _signup(client, email="inactivetpl@outfitter.dev")
    token = signup_resp.json()["access_token"]
    item = await _seed_item(db)
    template = await _seed_template(db, slug="hidden", is_active=False)
    _install_fakes(monkeypatch, db)

    body = _generate_body(item.id)
    body["template_id"] = str(template.id)

    response = await client.post(
        "/playground/generate-image",
        headers=_auth_headers(token),
        json=body,
    )
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_playground_optional_ids_omitted_works(
    client: AsyncClient, db, monkeypatch
):
    signup_resp = await _signup(client, email="noids@outfitter.dev")
    token = signup_resp.json()["access_token"]
    item = await _seed_item(db)
    _install_fakes(monkeypatch, db)

    response = await client.post(
        "/playground/generate-image",
        headers=_auth_headers(token),
        json=_generate_body(item.id),
    )
    assert response.status_code == 202

    runs = (await db.execute(select(PlaygroundRun))).scalars().all()
    assert runs[0].template_id is None
    assert runs[0].persona_id is None


# ---------------------------------------------------------------------------
# Snapshot persistence
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_playground_uses_active_system_prompt_snapshot(
    client: AsyncClient, db, monkeypatch
):
    signup_resp = await _signup(client, email="snapshot@outfitter.dev")
    token = signup_resp.json()["access_token"]
    item = await _seed_item(db)
    sp = await _seed_system_prompt(db, content="DB COPY")
    _install_fakes(monkeypatch, db)

    response = await client.post(
        "/playground/generate-image",
        headers=_auth_headers(token),
        json=_generate_body(item.id, system_prompt="REQUEST PROMPT"),
    )
    assert response.status_code == 202

    run = (await db.execute(select(PlaygroundRun))).scalars().one()
    assert run.system_prompt_id == sp.id
    # Snapshot is what the client sent, not the DB row content.
    assert run.system_prompt_text == "REQUEST PROMPT"


@pytest.mark.asyncio
async def test_playground_run_snapshot_fields_persisted(
    client: AsyncClient, db, monkeypatch
):
    signup_resp = await _signup(client, email="allfields@outfitter.dev")
    token = signup_resp.json()["access_token"]
    item = await _seed_item(db)
    sp = await _seed_system_prompt(db)
    template = await _seed_template(db, slug="evening_editorial")
    persona = await _seed_persona(db, slug="f_x", gender="female")
    _install_fakes(monkeypatch, db)

    body = _generate_body(
        item.id,
        system_prompt="SYS A",
        user_prompt="USR B",
        size="1024x1024",
        quality="medium",
        n=1,
    )
    body["template_id"] = str(template.id)
    body["persona_id"] = str(persona.id)

    response = await client.post(
        "/playground/generate-image", headers=_auth_headers(token), json=body
    )
    assert response.status_code == 202
    await _await_run_finish(client, db, token, response.json()["run_id"])

    run = (await db.execute(select(PlaygroundRun))).scalars().one()
    assert run.system_prompt_id == sp.id
    assert run.template_id == template.id
    assert run.persona_id == persona.id
    assert run.system_prompt_text == "SYS A"
    assert run.user_prompt_text == "USR B"
    assert run.final_prompt_text == "SYS A\n\nUSR B"
    assert run.size == "1024x1024"
    assert run.quality == "medium"
    assert run.n == 1
    assert len(run.image_keys) == 1
    assert run.model_name == "gpt-image-2"
    assert run.elapsed_ms >= 0
    assert run.status == "success"
    assert run.error_message is None
    assert run.deleted_at is None


# ---------------------------------------------------------------------------
# Daily cap
# ---------------------------------------------------------------------------


async def _run_n_successes(client, db, monkeypatch, *, email: str, n: int) -> str:
    signup_resp = await _signup(client, email=email)
    token = signup_resp.json()["access_token"]
    item = await _seed_item(db)
    _install_fakes(monkeypatch, db)
    for _ in range(n):
        resp = await client.post(
            "/playground/generate-image",
            headers=_auth_headers(token),
            json=_generate_body(item.id),
        )
        assert resp.status_code == 202, resp.text
        await _await_run_finish(client, db, token, resp.json()["run_id"])
    return token


@pytest.mark.asyncio
async def test_playground_daily_cap_blocks_sixth(
    client: AsyncClient, db, monkeypatch
):
    token = await _run_n_successes(
        client, db, monkeypatch, email="cap@outfitter.dev", n=5
    )
    item = (await db.execute(select(CatalogItem))).scalars().one()

    resp = await client.post(
        "/playground/generate-image",
        headers=_auth_headers(token),
        json=_generate_body(item.id),
    )
    assert resp.status_code == 429
    detail = resp.json()["detail"]
    assert detail["error"]["code"] == "DAILY_LIMIT_REACHED"
    assert detail["error"]["limit"] == 5
    assert detail["error"]["used"] == 5
    reset_at = datetime.fromisoformat(detail["error"]["reset_at"])
    assert reset_at > datetime.now(timezone.utc)


@pytest.mark.asyncio
async def test_playground_failed_runs_count_toward_cap_default(
    client: AsyncClient, db, monkeypatch
):
    from app.services.codex_image_service import CodexProxyError

    signup_resp = await _signup(client, email="failcap@outfitter.dev")
    token = signup_resp.json()["access_token"]
    item = await _seed_item(db)
    _install_fakes(monkeypatch, db, codex_raises=CodexProxyError("nope"))

    for _ in range(5):
        resp = await client.post(
            "/playground/generate-image",
            headers=_auth_headers(token),
            json=_generate_body(item.id),
        )
        assert resp.status_code == 202
        await _await_run_finish(client, db, token, resp.json()["run_id"])

    # 6th attempt — flip codex back to success but cap should still trigger.
    _install_fakes(monkeypatch, db)
    resp = await client.post(
        "/playground/generate-image",
        headers=_auth_headers(token),
        json=_generate_body(item.id),
    )
    assert resp.status_code == 429


@pytest.mark.asyncio
async def test_playground_failed_runs_excluded_when_flag_off(
    client: AsyncClient, db, monkeypatch
):
    from app.config import settings as app_settings
    from app.services.codex_image_service import CodexProxyError

    monkeypatch.setattr(
        app_settings, "PLAYGROUND_FAILED_RUNS_COUNT_TOWARD_CAP", False
    )

    signup_resp = await _signup(client, email="failexcl@outfitter.dev")
    token = signup_resp.json()["access_token"]
    item = await _seed_item(db)
    _install_fakes(monkeypatch, db, codex_raises=CodexProxyError("nope"))

    for _ in range(5):
        resp = await client.post(
            "/playground/generate-image",
            headers=_auth_headers(token),
            json=_generate_body(item.id),
        )
        assert resp.status_code == 202
        await _await_run_finish(client, db, token, resp.json()["run_id"])

    _install_fakes(monkeypatch, db)
    resp = await client.post(
        "/playground/generate-image",
        headers=_auth_headers(token),
        json=_generate_body(item.id),
    )
    assert resp.status_code == 202


# ---------------------------------------------------------------------------
# Read endpoints — system prompt, templates, personas
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_get_system_prompt_returns_active(client: AsyncClient, db):
    signup_resp = await _signup(client, email="sp1@outfitter.dev")
    token = signup_resp.json()["access_token"]
    await _seed_system_prompt(
        db, slug="old", content="OLD", is_active=False
    )
    active = await _seed_system_prompt(
        db, slug="global", content="ACTIVE", is_active=True
    )

    resp = await client.get(
        "/playground/system-prompt", headers=_auth_headers(token)
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["id"] == str(active.id)
    assert body["slug"] == "global"
    assert body["content"] == "ACTIVE"


@pytest.mark.asyncio
async def test_get_system_prompt_filters_inactive(client: AsyncClient, db):
    signup_resp = await _signup(client, email="sp2@outfitter.dev")
    token = signup_resp.json()["access_token"]
    await _seed_system_prompt(db, slug="g", is_active=False)

    resp = await client.get(
        "/playground/system-prompt", headers=_auth_headers(token)
    )
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_list_templates_filters_inactive(client: AsyncClient, db):
    signup_resp = await _signup(client, email="tpl@outfitter.dev")
    token = signup_resp.json()["access_token"]
    await _seed_template(db, slug="active1", label="A1", is_active=True)
    await _seed_template(db, slug="active2", label="A2", is_active=True)
    await _seed_template(db, slug="hidden", label="H", is_active=False)

    resp = await client.get("/playground/templates", headers=_auth_headers(token))
    assert resp.status_code == 200
    slugs = {row["slug"] for row in resp.json()}
    assert slugs == {"active1", "active2"}


@pytest.mark.asyncio
async def test_list_personas_gender_filter(client: AsyncClient, db):
    signup_resp = await _signup(client, email="pers@outfitter.dev")
    token = signup_resp.json()["access_token"]
    await _seed_persona(db, slug="f1", gender="female", label="F1")
    await _seed_persona(db, slug="f2", gender="female", label="F2")
    await _seed_persona(db, slug="m1", gender="male", label="M1")

    resp = await client.get(
        "/playground/personas?gender=female", headers=_auth_headers(token)
    )
    assert resp.status_code == 200
    rows = resp.json()
    assert len(rows) == 2
    assert all(r["gender"] == "female" for r in rows)

    resp_all = await client.get(
        "/playground/personas", headers=_auth_headers(token)
    )
    assert resp_all.status_code == 200
    assert len(resp_all.json()) == 3


# ---------------------------------------------------------------------------
# Read endpoints — runs history
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_list_runs_only_for_current_user(
    client: AsyncClient, db, monkeypatch
):
    item = await _seed_item(db)
    _install_fakes(monkeypatch, db)

    a_token = (await _signup(client, email="a@outfitter.dev")).json()["access_token"]
    b_token = (await _signup(client, email="b@outfitter.dev")).json()["access_token"]

    await client.post(
        "/playground/generate-image",
        headers=_auth_headers(a_token),
        json=_generate_body(item.id),
    )
    await client.post(
        "/playground/generate-image",
        headers=_auth_headers(b_token),
        json=_generate_body(item.id),
    )

    resp = await client.get("/playground/runs", headers=_auth_headers(a_token))
    assert resp.status_code == 200
    body = resp.json()
    assert len(body["items"]) == 1


@pytest.mark.asyncio
async def test_list_runs_excludes_soft_deleted(
    client: AsyncClient, db, monkeypatch
):
    item = await _seed_item(db)
    _install_fakes(monkeypatch, db)
    token = (await _signup(client, email="sd@outfitter.dev")).json()["access_token"]

    await client.post(
        "/playground/generate-image",
        headers=_auth_headers(token),
        json=_generate_body(item.id),
    )
    run = (await db.execute(select(PlaygroundRun))).scalars().one()
    run.deleted_at = datetime.now(timezone.utc)
    await db.commit()

    resp = await client.get("/playground/runs", headers=_auth_headers(token))
    assert resp.status_code == 200
    assert resp.json()["items"] == []


@pytest.mark.asyncio
async def test_get_run_404_for_other_user(client: AsyncClient, db, monkeypatch):
    item = await _seed_item(db)
    _install_fakes(monkeypatch, db)

    a_token = (await _signup(client, email="aa@outfitter.dev")).json()["access_token"]
    b_token = (await _signup(client, email="bb@outfitter.dev")).json()["access_token"]

    a_resp = await client.post(
        "/playground/generate-image",
        headers=_auth_headers(a_token),
        json=_generate_body(item.id),
    )
    run_id = a_resp.json()["run_id"]

    resp = await client.get(
        f"/playground/runs/{run_id}", headers=_auth_headers(b_token)
    )
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_get_run_returns_snapshot(client: AsyncClient, db, monkeypatch):
    item = await _seed_item(db)
    _install_fakes(monkeypatch, db)
    token = (await _signup(client, email="own@outfitter.dev")).json()[
        "access_token"
    ]

    post_resp = await client.post(
        "/playground/generate-image",
        headers=_auth_headers(token),
        json=_generate_body(
            item.id, system_prompt="SYS X", user_prompt="USR Y"
        ),
    )
    run_id = post_resp.json()["run_id"]
    await _simulate_finish(db, run_id)

    resp = await client.get(
        f"/playground/runs/{run_id}", headers=_auth_headers(token)
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["id"] == run_id
    assert body["system_prompt_text"] == "SYS X"
    assert body["user_prompt_text"] == "USR Y"
    assert body["final_prompt_text"] == "SYS X\n\nUSR Y"
    assert body["status"] == "success"
    assert len(body["images"]) == 1
    assert body["images"][0].startswith("https://signed/")


@pytest.mark.asyncio
async def test_list_runs_cursor_pagination(
    client: AsyncClient, db, monkeypatch
):
    item = await _seed_item(db)
    _install_fakes(monkeypatch, db)
    token = (await _signup(client, email="page@outfitter.dev")).json()[
        "access_token"
    ]

    # Seed 25 runs directly in the DB so we don't hit the daily cap (which is 5).
    user = (
        await db.execute(
            select(__import__("app.models.user", fromlist=["User"]).User)
        )
    ).scalars().one()
    base_time = datetime.now(timezone.utc)
    for i in range(25):
        db.add(
            PlaygroundRun(
                user_id=user.id,
                catalog_item_ids=[str(item.id)],
                system_prompt_text="x",
                user_prompt_text="",
                final_prompt_text="x",
                size="1024x1536",
                quality="high",
                n=1,
                image_keys=[],
                model_name="gpt-image-2",
                elapsed_ms=10,
                status="success",
                error_message=None,
                created_at=base_time - timedelta(seconds=i),
            )
        )
    await db.commit()

    resp1 = await client.get(
        "/playground/runs?limit=20", headers=_auth_headers(token)
    )
    assert resp1.status_code == 200
    page1 = resp1.json()
    assert len(page1["items"]) == 20
    assert page1["next_cursor"] is not None

    resp2 = await client.get(
        f"/playground/runs?limit=20&cursor={page1['next_cursor']}",
        headers=_auth_headers(token),
    )
    assert resp2.status_code == 200
    page2 = resp2.json()
    assert len(page2["items"]) == 5
    assert page2["next_cursor"] is None


# ---------------------------------------------------------------------------
# Admin write endpoints — system prompt / templates / personas
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_admin_patch_system_prompt(client: AsyncClient, db):
    sp = await _seed_system_prompt(db, content="OLD", label="Old label")
    token = await _signup_admin(client, db, email="admin1@outfitter.dev")

    resp = await client.patch(
        "/playground/system-prompt",
        headers=_auth_headers(token),
        json={"content": "NEW", "label": "New label"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["content"] == "NEW"
    assert body["label"] == "New label"
    assert body["id"] == str(sp.id)


@pytest.mark.asyncio
async def test_non_admin_patch_system_prompt_403(client: AsyncClient, db):
    await _seed_system_prompt(db)
    token = (await _signup(client, email="user1@outfitter.dev")).json()[
        "access_token"
    ]

    resp = await client.patch(
        "/playground/system-prompt",
        headers=_auth_headers(token),
        json={"content": "NEW"},
    )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_admin_create_template(client: AsyncClient, db):
    token = await _signup_admin(client, db, email="admin2@outfitter.dev")

    resp = await client.post(
        "/playground/templates",
        headers=_auth_headers(token),
        json={
            "slug": "my_new_tpl",
            "label": "My New Template",
            "description": "Created from API",
            "body": "Render {{MODEL}} in studio.",
        },
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["slug"] == "my_new_tpl"
    assert body["is_active"] is True


@pytest.mark.asyncio
async def test_create_template_bad_slug_pattern_422(client: AsyncClient, db):
    token = await _signup_admin(client, db, email="admin3@outfitter.dev")

    resp = await client.post(
        "/playground/templates",
        headers=_auth_headers(token),
        json={
            "slug": "Has-Caps",
            "label": "x",
            "body": "{{MODEL}}",
        },
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_create_template_duplicate_slug_409(client: AsyncClient, db):
    token = await _signup_admin(client, db, email="admin4@outfitter.dev")
    await _seed_template(db, slug="dupe")

    resp = await client.post(
        "/playground/templates",
        headers=_auth_headers(token),
        json={"slug": "dupe", "label": "x", "body": "{{MODEL}}"},
    )
    assert resp.status_code == 409


@pytest.mark.asyncio
async def test_non_admin_create_template_403(client: AsyncClient, db):
    token = (await _signup(client, email="user2@outfitter.dev")).json()[
        "access_token"
    ]

    resp = await client.post(
        "/playground/templates",
        headers=_auth_headers(token),
        json={"slug": "x_y_z", "label": "x", "body": "{{MODEL}}"},
    )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_admin_patch_template(client: AsyncClient, db):
    token = await _signup_admin(client, db, email="admin5@outfitter.dev")
    tpl = await _seed_template(db, slug="patchme", body="old body")

    resp = await client.patch(
        f"/playground/templates/{tpl.id}",
        headers=_auth_headers(token),
        json={"body": "new body", "label": "new label"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["body"] == "new body"
    assert body["label"] == "new label"


@pytest.mark.asyncio
async def test_admin_soft_delete_and_restore_template(
    client: AsyncClient, db
):
    token = await _signup_admin(client, db, email="admin6@outfitter.dev")
    tpl = await _seed_template(db, slug="killme")

    resp = await client.delete(
        f"/playground/templates/{tpl.id}",
        headers=_auth_headers(token),
    )
    assert resp.status_code == 204

    # Hidden from default list
    listing = await client.get(
        "/playground/templates", headers=_auth_headers(token)
    )
    assert all(r["slug"] != "killme" for r in listing.json())

    # Visible with include_inactive (admin only)
    listing_all = await client.get(
        "/playground/templates?include_inactive=true",
        headers=_auth_headers(token),
    )
    assert any(
        r["slug"] == "killme" and r["is_active"] is False
        for r in listing_all.json()
    )

    # Restore via PATCH
    resp = await client.patch(
        f"/playground/templates/{tpl.id}",
        headers=_auth_headers(token),
        json={"is_active": True},
    )
    assert resp.status_code == 200
    assert resp.json()["is_active"] is True


@pytest.mark.asyncio
async def test_include_inactive_requires_admin(client: AsyncClient, db):
    token = (await _signup(client, email="user3@outfitter.dev")).json()[
        "access_token"
    ]

    resp = await client.get(
        "/playground/templates?include_inactive=true",
        headers=_auth_headers(token),
    )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_admin_create_persona(client: AsyncClient, db):
    token = await _signup_admin(client, db, email="admin7@outfitter.dev")

    resp = await client.post(
        "/playground/personas",
        headers=_auth_headers(token),
        json={
            "slug": "f_test",
            "label": "Test Persona",
            "gender": "female",
            "description": "- mid-20s\n- tan skin",
        },
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["slug"] == "f_test"
    assert body["gender"] == "female"
    assert body["is_active"] is True


@pytest.mark.asyncio
async def test_persona_gender_immutable_on_patch(client: AsyncClient, db):
    token = await _signup_admin(client, db, email="admin8@outfitter.dev")
    p = await _seed_persona(db, slug="immutable", gender="female")

    # PersonaUpdate has no gender field, so this is a 422 (extra field forbidden
    # by Pydantic v2 by default? Actually default is to ignore. Test expectation:
    # extras silently ignored, gender stays female).
    resp = await client.patch(
        f"/playground/personas/{p.id}",
        headers=_auth_headers(token),
        json={"gender": "male", "label": "Renamed"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["gender"] == "female"  # unchanged
    assert body["label"] == "Renamed"  # changed


@pytest.mark.asyncio
async def test_admin_soft_delete_persona(client: AsyncClient, db):
    token = await _signup_admin(client, db, email="admin9@outfitter.dev")
    p = await _seed_persona(db, slug="dyingpersona")

    resp = await client.delete(
        f"/playground/personas/{p.id}",
        headers=_auth_headers(token),
    )
    assert resp.status_code == 204

    listing = await client.get(
        "/playground/personas", headers=_auth_headers(token)
    )
    assert all(r["slug"] != "dyingpersona" for r in listing.json())


@pytest.mark.asyncio
async def test_user_role_in_auth_me(client: AsyncClient, db):
    token = await _signup_admin(client, db, email="admin10@outfitter.dev")

    resp = await client.get(
        "/auth/me", headers=_auth_headers(token)
    )
    assert resp.status_code == 200
    assert resp.json()["role"] == "admin"
