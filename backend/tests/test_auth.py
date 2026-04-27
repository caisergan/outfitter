"""
Integration tests for authentication flows.
"""

import pytest
from httpx import AsyncClient


SIGNUP_URL = "/auth/signup"
LOGIN_URL = "/auth/login"
REFRESH_URL = "/auth/refresh"
ME_URL = "/auth/me"

VALID_EMAIL = "sofia@outfitter.dev"
VALID_PASSWORD = "supersecret99"


async def _signup(
    client: AsyncClient,
    email: str = VALID_EMAIL,
    password: str = VALID_PASSWORD,
):
    return await client.post(SIGNUP_URL, json={"email": email, "password": password})


async def _login(
    client: AsyncClient,
    email: str = VALID_EMAIL,
    password: str = VALID_PASSWORD,
):
    return await client.post(
        LOGIN_URL,
        data={"username": email, "password": password},
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )


@pytest.mark.asyncio
async def test_signup_success(client: AsyncClient):
    resp = await _signup(client)
    assert resp.status_code == 201
    body = resp.json()
    assert "access_token" in body
    assert "refresh_token" in body
    assert body["token_type"] == "bearer"
    assert len(body["access_token"]) > 20
    assert len(body["refresh_token"]) > 20


@pytest.mark.asyncio
async def test_signup_duplicate_email_returns_409(client: AsyncClient):
    await _signup(client)
    resp = await _signup(client)
    assert resp.status_code == 409
    assert "already registered" in resp.json()["detail"].lower()


@pytest.mark.asyncio
async def test_signup_duplicate_email_case_insensitive_returns_409(client: AsyncClient):
    await _signup(client, email="CaseUser@Outfitter.dev")
    resp = await _signup(client, email="caseuser@outfitter.dev")
    assert resp.status_code == 409
    assert "already registered" in resp.json()["detail"].lower()


@pytest.mark.asyncio
async def test_signup_invalid_email_returns_422(client: AsyncClient):
    resp = await client.post(
        SIGNUP_URL,
        json={"email": "not-an-email", "password": VALID_PASSWORD},
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_signup_short_password_returns_422(client: AsyncClient):
    resp = await client.post(SIGNUP_URL, json={"email": VALID_EMAIL, "password": "short"})
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_login_success(client: AsyncClient):
    await _signup(client)
    resp = await _login(client)
    assert resp.status_code == 200
    body = resp.json()
    assert "access_token" in body
    assert "refresh_token" in body
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


@pytest.mark.asyncio
async def test_login_email_is_case_insensitive(client: AsyncClient):
    await _signup(client, email="MixedCase@Outfitter.dev")
    resp = await _login(client, email="mixedcase@outfitter.dev")
    assert resp.status_code == 200
    assert "access_token" in resp.json()


@pytest.mark.asyncio
async def test_refresh_with_valid_refresh_token_returns_new_tokens(client: AsyncClient):
    signup_resp = await _signup(client, email="refreshable@outfitter.dev")
    refresh_token = signup_resp.json()["refresh_token"]

    resp = await client.post(REFRESH_URL, json={"refresh_token": refresh_token})
    assert resp.status_code == 200
    body = resp.json()
    assert "access_token" in body
    assert "refresh_token" in body
    assert body["token_type"] == "bearer"


@pytest.mark.asyncio
async def test_refresh_rejects_access_token(client: AsyncClient):
    signup_resp = await _signup(client, email="refresh-reject@outfitter.dev")
    access_token = signup_resp.json()["access_token"]

    resp = await client.post(REFRESH_URL, json={"refresh_token": access_token})
    assert resp.status_code == 401
    assert "refresh" in resp.json()["detail"].lower()


@pytest.mark.asyncio
async def test_refresh_rejects_tampered_token(client: AsyncClient):
    resp = await client.post(REFRESH_URL, json={"refresh_token": "tampered.token.value"})
    assert resp.status_code == 401
    assert "refresh" in resp.json()["detail"].lower()


@pytest.mark.asyncio
async def test_me_with_valid_token(client: AsyncClient):
    signup_resp = await _signup(client, email="UpperCase@Outfitter.dev")
    token = signup_resp.json()["access_token"]

    resp = await client.get(ME_URL, headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200
    body = resp.json()
    assert body["email"] == "uppercase@outfitter.dev"
    assert "id" in body
    assert "created_at" in body
    assert "password_hash" not in body


@pytest.mark.asyncio
async def test_me_without_token_returns_401(client: AsyncClient):
    resp = await client.get(ME_URL)
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_me_with_tampered_token_returns_401(client: AsyncClient):
    resp = await client.get(
        ME_URL,
        headers={"Authorization": "Bearer tampered.token.value"},
    )
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_me_with_malformed_bearer_returns_401(client: AsyncClient):
    resp = await client.get(ME_URL, headers={"Authorization": "NotBearer sometoken"})
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_full_auth_flow(client: AsyncClient):
    signup_resp = await _signup(client)
    assert signup_resp.status_code == 201
    signup_token = signup_resp.json()["access_token"]
    signup_refresh = signup_resp.json()["refresh_token"]

    login_resp = await _login(client)
    assert login_resp.status_code == 200
    login_token = login_resp.json()["access_token"]
    login_refresh = login_resp.json()["refresh_token"]

    for token in (signup_token, login_token):
        resp = await client.get(ME_URL, headers={"Authorization": f"Bearer {token}"})
        assert resp.status_code == 200
        assert resp.json()["email"] == VALID_EMAIL

    for refresh_token in (signup_refresh, login_refresh):
        resp = await client.post(REFRESH_URL, json={"refresh_token": refresh_token})
        assert resp.status_code == 200
        assert "access_token" in resp.json()
