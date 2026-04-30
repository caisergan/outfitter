"""
Shared test fixtures for the Outfitter test suite.

Uses an in-process SQLite async engine (via aiosqlite) so tests run without
a real Postgres instance. PostgreSQL-specific types (pgvector Vector, ARRAY,
UUID) are monkey-patched to SQLite-compatible equivalents *before* any model
module is imported.

**Import order matters**: patches are applied before ``app.models`` is
touched, so models pick up the compat types on their first (and only)
import — no ``importlib.reload()`` needed.
"""

from collections.abc import AsyncGenerator

import pytest_asyncio
from sqlalchemy import JSON as _JSON
from sqlalchemy import String as _String
from sqlalchemy import Text as _Text

# ---------------------------------------------------------------------------
# 1. Patch Postgres-only types → SQLite equivalents BEFORE model imports
# ---------------------------------------------------------------------------

# pgvector Vector(512) → Text
import pgvector.sqlalchemy as _pgv  # noqa: E402


class _VectorCompat(_Text):  # type: ignore[misc]
    """Drop-in for ``Vector(n)`` that works on SQLite."""

    def __init__(self, *_args, **_kwargs) -> None:  # noqa: ANN002, ANN003
        super().__init__()


_pgv.Vector = _VectorCompat  # type: ignore[attr-defined]

# ARRAY(String) → JSON  (SQLite stores as JSON text)
import sqlalchemy as _sa  # noqa: E402


class _ArrayCompat(_JSON):  # type: ignore[misc]
    """Drop-in for ``ARRAY(item_type)`` that works on SQLite."""

    def __init__(self, *_args, **_kwargs) -> None:  # noqa: ANN002, ANN003
        super().__init__()


_sa.ARRAY = _ArrayCompat  # type: ignore[attr-defined,misc]

# UUID(as_uuid=True) → String(36) with automatic str↔UUID conversion
import uuid as _uuid_mod  # noqa: E402

import sqlalchemy.dialects.postgresql as _pg  # noqa: E402
from sqlalchemy.types import TypeDecorator as _TypeDecorator  # noqa: E402


class _UUIDCompat(_TypeDecorator):  # type: ignore[misc]
    """Drop-in for PostgreSQL ``UUID(as_uuid=True)`` that works on SQLite.

    Stores UUIDs as 36-char strings and converts back to ``uuid.UUID``
    on retrieval so the same Python code works on both backends.
    """

    impl = _String
    cache_ok = True

    def __init__(self, *_args, **_kwargs) -> None:  # noqa: ANN002, ANN003
        super().__init__()
        self.impl = _String(36)

    def process_bind_param(self, value, dialect):  # noqa: ANN001, ANN201
        if value is not None:
            return str(value)
        return value

    def process_result_value(self, value, dialect):  # noqa: ANN001, ANN201
        if value is not None:
            return _uuid_mod.UUID(value)
        return value


_pg.UUID = _UUIDCompat  # type: ignore[attr-defined,misc]
_pg.JSONB = _JSON  # type: ignore[attr-defined,misc]

# ---------------------------------------------------------------------------
# 2. NOW import the app — models will use the patched types
# ---------------------------------------------------------------------------
from httpx import ASGITransport, AsyncClient  # noqa: E402
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine  # noqa: E402
from sqlalchemy.orm import sessionmaker  # noqa: E402
from sqlalchemy.pool import StaticPool  # noqa: E402

from app.database import Base, get_db  # noqa: E402
from app.main import app as fastapi_app  # noqa: E402

# Force all model modules to register with Base.metadata
import app.models.user  # noqa: F401, E402
import app.models.catalog  # noqa: F401, E402
import app.models.wardrobe  # noqa: F401, E402
import app.models.outfit  # noqa: F401, E402
import app.models.tryon  # noqa: F401, E402

# ---------------------------------------------------------------------------
# 3. Async SQLite engine (one per session; tables recreated per test)
# ---------------------------------------------------------------------------
TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"

_engine = create_async_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
_TestSession = sessionmaker(_engine, class_=AsyncSession, expire_on_commit=False)


@pytest_asyncio.fixture(scope="function", autouse=False)
async def db() -> AsyncGenerator[AsyncSession, None]:
    async with _engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with _TestSession() as session:
        yield session

    async with _engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest_asyncio.fixture
async def client(db: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """AsyncClient wired to the FastAPI app with DB overridden to test session."""

    async def _override_get_db():
        yield db

    fastapi_app.dependency_overrides[get_db] = _override_get_db
    async with AsyncClient(
        transport=ASGITransport(app=fastapi_app), base_url="http://test"
    ) as ac:
        yield ac
    fastapi_app.dependency_overrides.clear()
