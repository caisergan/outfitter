from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.jwt import (
    CurrentUserDep,
    create_access_token,
    create_refresh_token,
    get_token_subject,
)
from app.auth.password import get_password_hash, verify_password
from app.database import get_db
from app.models.user import User
from app.schemas.auth import RefreshTokenRequest, SignupRequest, TokenResponse
from app.schemas.user import UserResponse

router = APIRouter(prefix="/auth", tags=["auth"])

DbDep = Annotated[AsyncSession, Depends(get_db)]


def _issue_tokens(user: User) -> TokenResponse:
    return TokenResponse(
        access_token=create_access_token({"sub": user.id}),
        refresh_token=create_refresh_token({"sub": user.id}),
    )


@router.post("/signup", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def signup(body: SignupRequest, db: DbDep) -> TokenResponse:
    normalized_email = body.email.strip().lower()
    result = await db.execute(select(User).where(func.lower(User.email) == normalized_email))
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already registered",
        )

    user = User(email=normalized_email, password_hash=get_password_hash(body.password))
    db.add(user)
    await db.flush()
    await db.refresh(user)
    return _issue_tokens(user)


@router.post("/login", response_model=TokenResponse)
async def login(
    form_data: Annotated[OAuth2PasswordRequestForm, Depends()],
    db: DbDep,
) -> TokenResponse:
    normalized_email = form_data.username.strip().lower()
    result = await db.execute(select(User).where(func.lower(User.email) == normalized_email))
    users = result.scalars().all()
    user = next(
        (
            candidate
            for candidate in users
            if verify_password(form_data.password, candidate.password_hash)
        ),
        None,
    )

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return _issue_tokens(user)


@router.post("/refresh", response_model=TokenResponse)
async def refresh_session(body: RefreshTokenRequest, db: DbDep) -> TokenResponse:
    user_id = get_token_subject(
        body.refresh_token,
        expected_type="refresh",
        detail="Could not refresh session",
    )
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not refresh session",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return _issue_tokens(user)


@router.get("/me", response_model=UserResponse)
async def me(current_user: CurrentUserDep) -> UserResponse:
    return UserResponse.model_validate(current_user)
