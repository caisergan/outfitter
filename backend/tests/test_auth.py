"""
Integration tests for Phase 3: Authentication.

Covers every scenario from the task breakdown:
  - POST /auth/signup  → success, duplicate email
  - POST /auth/login   → success, wrong password, unknown email
  - GET  /auth/me      → success, missing token, tampered token
  - Full flow: signup → login → protected endpoint
"""
import pytest
from httpx import AsyncClient


SIGNUP_URL = "/auth/signup"
LOGIN_URL = "/auth/login"
ME_URL = "/auth/me"

VALID_EMAIL = "sofia@outfitter.dev"
VALID_PASSWORD = "supersecret99"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

async def _signup(client: AsyncClient, email: str = VALID_EMAIL, password: str = VALID_PASSWORD):
    return await client.post(SIGNUP_URL, json={"email": email, "password": password})


async def _login(client: AsyncClient, email: str = VALID_EMAIL, password: str = VALID_PASSWORD):
    return await client.post(
        LOGIN_URL,
        data={"username": email, "password": password},
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )


# ---------------------------------------------------------------------------
# Signup
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_signup_success(client: AsyncClient):
    resp = await _signup(client)
    assert resp.status_code == 201
    body = resp.json()
    assert "access_token" in body
    assert body["token_type"] == "bearer"
    assert len(body["access_token"]) > 20


@pytest.mark.asyncio
async def test_signup_duplicate_email_returns_409(client: AsyncClient):
    await _signup(client)  # first signup succeeds
    resp = await _signup(client)  # second with same email
    assert resp.status_code == 409
    assert "already registered" in resp.json()["detail"].lower()


@pytest.mark.asyncio
async def test_signup_invalid_email_returns_422(client: AsyncClient):
    resp = await client.post(SIGNUP_URL, json={"email": "not-an-email", "password": VALID_PASSWORD})
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_signup_short_password_returns_422(client: AsyncClient):
    resp = await client.post(SIGNUP_URL, json={"email": VALID_EMAIL, "password": "short"})
    assert resp.status_code == 422


# ---------------------------------------------------------------------------
# Login
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_login_success(client: AsyncClient):
    await _signup(client)
    resp = await _login(client)
    assert resp.status_code == 200
    body = resp.json()
    assert "access_token" in body
    assert body["token_type"] == "bearer"


@pytest.mark.asyncio
async def test_login_wrong_password_returns_401(client: AsyncClient):
    await _signup(client)
    resp = await _login(client, password="wrongpassword")
    assert resp.status_code == 401
    assert resp.headers.get("www-authenticate") == "Bearer"


@pytest.mark.asyncio
async def test_login_unknown_email_returns_401(client: AsyncClient):
    resp = await _login(client, email="ghost@outfitter.test")
    assert resp.status_code == 401


# ---------------------------------------------------------------------------
# Protected endpoint: GET /auth/me
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_me_with_valid_token(client: AsyncClient):
    signup_resp = await _signup(client)
    token = signup_resp.json()["access_token"]

    resp = await client.get(ME_URL, headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200
    body = resp.json()
    assert body["email"] == VALID_EMAIL
    assert "id" in body
    assert "created_at" in body
    # password_hash must never be leaked
    assert "password_hash" not in body


@pytest.mark.asyncio
async def test_me_without_token_returns_401(client: AsyncClient):
    resp = await client.get(ME_URL)
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_me_with_tampered_token_returns_401(client: AsyncClient):
    resp = await client.get(ME_URL, headers={"Authorization": "Bearer tampered.token.value"})
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_me_with_malformed_bearer_returns_401(client: AsyncClient):
    resp = await client.get(ME_URL, headers={"Authorization": "NotBearer sometoken"})
    assert resp.status_code == 401


# ---------------------------------------------------------------------------
# Full flow: signup → login → protected endpoint
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_full_auth_flow(client: AsyncClient):
    # 1. Signup
    signup_resp = await _signup(client)
    assert signup_resp.status_code == 201
    signup_token = signup_resp.json()["access_token"]

    # 2. Login with same credentials → distinct token (different exp)
    login_resp = await _login(client)
    assert login_resp.status_code == 200
    login_token = login_resp.json()["access_token"]

    # Both tokens should grant access to /auth/me
    for token in (signup_token, login_token):
        resp = await client.get(ME_URL, headers={"Authorization": f"Bearer {token}"})
        assert resp.status_code == 200
        assert resp.json()["email"] == VALID_EMAIL
