from __future__ import annotations

from fastapi import APIRouter, Depends

from app.core.dependencies import CurrentUserId, DbSession
from app.schemas.auth import (
    AuthResponse,
    ForgotPasswordRequest,
    GoogleAuthRequest,
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
)
from app.schemas.common import ApiMessageResponse
from app.services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=AuthResponse, status_code=201)
async def register(req: RegisterRequest, db: DbSession) -> AuthResponse:
    """Register a new Guardian AI user."""
    svc = AuthService(db)
    return await svc.register(req)


@router.post("/login", response_model=AuthResponse)
async def login(req: LoginRequest, db: DbSession) -> AuthResponse:
    """Login with email and password."""
    svc = AuthService(db)
    return await svc.login(req)


@router.post("/google", response_model=AuthResponse)
async def google_login(req: GoogleAuthRequest, db: DbSession) -> AuthResponse:
    """Sign in with Google ID token."""
    svc = AuthService(db)
    return await svc.login_with_google(req)


@router.post("/refresh", response_model=AuthResponse)
async def refresh(req: RefreshRequest, db: DbSession) -> AuthResponse:
    """Rotate a refresh token and issue a new access token."""
    svc = AuthService(db)
    return await svc.refresh(req.refresh_token)


@router.post("/logout", response_model=ApiMessageResponse)
async def logout(user_id: CurrentUserId, db: DbSession) -> ApiMessageResponse:
    """Revoke all refresh tokens for the current user."""
    svc = AuthService(db)
    await svc.logout(user_id)
    return ApiMessageResponse(success=True, message="Logged out successfully.")


@router.post("/forgot-password", response_model=ApiMessageResponse)
async def forgot_password(req: ForgotPasswordRequest, db: DbSession) -> ApiMessageResponse:
    """Request a password reset (email-based flow)."""
    svc = AuthService(db)
    await svc.forgot_password(req.email)
    return ApiMessageResponse(
        success=True,
        message="If an account with that email exists, a reset link has been sent.",
    )
