from __future__ import annotations

import uuid
from contextvars import ContextVar
from typing import Annotated

from fastapi import Depends, Header, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.database import get_db
from app.core.exceptions import InvalidTokenError, UnauthorizedError
from app.core.security import decode_access_token

settings = get_settings()

# ─── Request ID ───────────────────────────────────────────────────────────────
request_id_ctx: ContextVar[str] = ContextVar("request_id", default="")

bearer_scheme = HTTPBearer(auto_error=False)


# ─── Auth Dependency ──────────────────────────────────────────────────────────

async def get_current_user_id(
    credentials: Annotated[
        HTTPAuthorizationCredentials | None, Depends(bearer_scheme)
    ] = None,
) -> str:
    """
    Extract and validate the JWT from the Authorization: Bearer header.
    Returns the user_id (sub) claim.
    Raises UnauthorizedError if token is missing or invalid.
    """
    if credentials is None:
        raise UnauthorizedError("Authorization header is required.")
    try:
        payload = decode_access_token(credentials.credentials)
        user_id: str = payload["sub"]
        return user_id
    except JWTError as exc:
        raise InvalidTokenError(str(exc)) from exc


async def get_optional_user_id(
    credentials: Annotated[
        HTTPAuthorizationCredentials | None, Depends(bearer_scheme)
    ] = None,
) -> str | None:
    """Like get_current_user_id but returns None instead of raising."""
    if credentials is None:
        return None
    try:
        payload = decode_access_token(credentials.credentials)
        return payload["sub"]
    except JWTError:
        return None


# ─── Typed Annotated Aliases ─────────────────────────────────────────────────
CurrentUserId = Annotated[str, Depends(get_current_user_id)]
OptionalUserId = Annotated[str | None, Depends(get_optional_user_id)]
DbSession = Annotated[AsyncSession, Depends(get_db)]
