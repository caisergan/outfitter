from datetime import datetime, timedelta, timezone
from typing import Annotated
import uuid

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db

ALGORITHM = "HS256"
ACCESS_TOKEN_TYPE = "access"
REFRESH_TOKEN_TYPE = "refresh"
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")


def _credentials_exception(detail: str = "Could not validate credentials") -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers={"WWW-Authenticate": "Bearer"},
    )


def _create_token(
    data: dict,
    *,
    token_type: str,
    expires_delta: timedelta,
) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + expires_delta
    to_encode["exp"] = expire
    to_encode["type"] = token_type
    if "sub" in to_encode and not isinstance(to_encode["sub"], str):
        to_encode["sub"] = str(to_encode["sub"])
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=ALGORITHM)


def create_access_token(data: dict, expires_delta: timedelta | None = None) -> str:
    return _create_token(
        data,
        token_type=ACCESS_TOKEN_TYPE,
        expires_delta=expires_delta
        or timedelta(days=settings.ACCESS_TOKEN_EXPIRE_DAYS),
    )


def create_refresh_token(data: dict, expires_delta: timedelta | None = None) -> str:
    return _create_token(
        data,
        token_type=REFRESH_TOKEN_TYPE,
        expires_delta=expires_delta
        or timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
    )


def get_token_subject(
    token: str,
    *,
    expected_type: str = ACCESS_TOKEN_TYPE,
    detail: str = "Could not validate credentials",
) -> uuid.UUID:
    credentials_exc = _credentials_exception(detail)
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[ALGORITHM])
        user_id_raw: str | None = payload.get("sub")
        token_type = payload.get("type", ACCESS_TOKEN_TYPE)
        if user_id_raw is None or token_type != expected_type:
            raise credentials_exc
        return uuid.UUID(user_id_raw)
    except (JWTError, ValueError):
        raise credentials_exc


async def get_current_user(
    token: Annotated[str, Depends(oauth2_scheme)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    from app.models.user import User

    user_id = get_token_subject(token, expected_type=ACCESS_TOKEN_TYPE)
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise _credentials_exception()
    return user


from app.models.user import User as _User  # noqa: E402

CurrentUserDep = Annotated[_User, Depends(get_current_user)]
