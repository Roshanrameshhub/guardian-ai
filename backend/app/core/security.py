from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import get_settings

settings = get_settings()

# ─── Password hashing ─────────────────────────────────────────────────────────
pwd_context = CryptContext(
    schemes=["pbkdf2_sha256", "bcrypt", "argon2"], deprecated="auto"
)


def hash_password(plain: str) -> str:
    """Return a secure hash of the plaintext password."""
    return pwd_context.hash(plain)


def verify_password(plain: str, hashed: str) -> bool:
    """Verify a plaintext password against its hash."""
    return pwd_context.verify(plain, hashed)


# ─── JWT helpers ──────────────────────────────────────────────────────────────

def _now_utc() -> datetime:
    return datetime.now(tz=timezone.utc)


def create_access_token(user_id: str, extra: dict[str, Any] | None = None) -> str:
    """Create a short-lived JWT access token."""
    payload: dict[str, Any] = {
        "sub": user_id,
        "type": "access",
        "iat": _now_utc(),
        "exp": _now_utc() + timedelta(minutes=settings.jwt_access_expire_minutes),
    }
    if extra:
        payload.update(extra)
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def create_refresh_token(user_id: str) -> str:
    """Create a long-lived JWT refresh token with unique jti entropy."""
    import uuid
    payload: dict[str, Any] = {
        "sub": user_id,
        "type": "refresh",
        "jti": str(uuid.uuid4()),
        "iat": _now_utc(),
        "exp": _now_utc() + timedelta(days=settings.jwt_refresh_expire_days),
    }
    return jwt.encode(
        payload, settings.jwt_refresh_secret, algorithm=settings.jwt_algorithm
    )


def decode_access_token(token: str) -> dict[str, Any]:
    """Decode and validate an access token. Raises JWTError on failure."""
    payload = jwt.decode(
        token, settings.jwt_secret, algorithms=[settings.jwt_algorithm]
    )
    if payload.get("type") != "access":
        raise JWTError("Not an access token")
    return payload


def decode_refresh_token(token: str) -> dict[str, Any]:
    """Decode and validate a refresh token. Raises JWTError on failure."""
    payload = jwt.decode(
        token, settings.jwt_refresh_secret, algorithms=[settings.jwt_algorithm]
    )
    if payload.get("type") != "refresh":
        raise JWTError("Not a refresh token")
    return payload


def extract_user_id(token: str) -> str:
    """Extract user_id (sub) from a valid access token."""
    return decode_access_token(token)["sub"]
