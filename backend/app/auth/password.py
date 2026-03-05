"""Password hashing utilities using bcrypt directly.

passlib is not compatible with bcrypt >= 4.1 on Python 3.12+, so we call
the ``bcrypt`` library directly for both hashing and verification.
Cost factor is fixed at 12 (matches the PRD requirement).
"""

import bcrypt

_COST_FACTOR = 12


def get_password_hash(password: str) -> str:
    """Hash a plaintext password with bcrypt (cost factor 12)."""
    salt = bcrypt.gensalt(rounds=_COST_FACTOR)
    return bcrypt.hashpw(password.encode("utf-8"), salt).decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a plaintext password against a bcrypt hash."""
    return bcrypt.checkpw(
        plain_password.encode("utf-8"),
        hashed_password.encode("utf-8"),
    )
