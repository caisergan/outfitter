from datetime import timedelta
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.jwt import CurrentUserDep, create_access_token
from app.auth.password import get_password_hash, verify_password
from app.config import settings
from app.database import get_db
from app.models.user import User
from app.schemas.auth import SignupRequest, TokenResponse
from app.schemas.user import UserResponse

router = APIRouter(prefix="/auth", tags=["auth"])

DbDep = Annotated[AsyncSession, Depends(get_db)]


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

    token = create_access_token(
        {"sub": user.id},
        expires_delta=timedelta(days=settings.ACCESS_TOKEN_EXPIRE_DAYS),
    )
    return TokenResponse(access_token=token)


@router.post("/login", response_model=TokenResponse)
async def login(
    form_data: Annotated[OAuth2PasswordRequestForm, Depends()],
    db: DbDep,
) -> TokenResponse:
    normalized_email = form_data.username.strip().lower()
    result = await db.execute(select(User).where(func.lower(User.email) == normalized_email))
    users = result.scalars().all()
    user = next(
        (candidate for candidate in users if verify_password(form_data.password, candidate.password_hash)),
        None,
    )

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = create_access_token(
        {"sub": user.id},
        expires_delta=timedelta(days=settings.ACCESS_TOKEN_EXPIRE_DAYS),
    )
    return TokenResponse(access_token=token)


@router.get("/me", response_model=UserResponse)
async def me(current_user: CurrentUserDep) -> UserResponse:
    return UserResponse.model_validate(current_user)
