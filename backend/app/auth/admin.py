"""Admin role gate.

Drop-in dependency for FastAPI routes that should only be reachable by users
whose ``users.role == 'admin'``. Returns the ``User`` row so handlers don't
need to re-resolve it.
"""
from typing import Annotated

from fastapi import Depends, HTTPException, status

from app.auth.jwt import get_current_user
from app.models.user import User


async def require_admin(
    current_user: Annotated[User, Depends(get_current_user)],
) -> User:
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required",
        )
    return current_user
