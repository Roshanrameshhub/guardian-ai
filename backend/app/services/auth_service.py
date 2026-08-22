from __future__ import annotations

import hashlib
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import (
    EmailAlreadyExistsError,
    InvalidCredentialsError,
    InvalidTokenError,
    NotFoundError,
)
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_refresh_token,
    hash_password,
    verify_password,
)
from app.models.user import RefreshToken, User, UserPreference, UserProfile
from app.schemas.auth import AuthResponse, GoogleAuthRequest, LoginRequest, RegisterRequest

settings = get_settings()


def _hash_token(token: str) -> str:
    """Store only a hash of the refresh token, not the token itself."""
    return hashlib.sha256(token.encode()).hexdigest()


class AuthService:
    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def register(self, req: RegisterRequest) -> AuthResponse:
        # Check email uniqueness
        existing = await self._db.scalar(
            select(User).where(User.email == req.email.lower())
        )
        if existing:
            raise EmailAlreadyExistsError()

        # Create user
        user = User(
            email=req.email.lower(),
            password_hash=hash_password(req.password),
            full_name=req.full_name,
            phone=req.phone,
        )
        self._db.add(user)
        await self._db.flush()  # get user.id

        # Create profile
        profile = UserProfile(user_id=user.id)
        self._db.add(profile)

        # Create default preferences
        prefs = UserPreference(user_id=user.id)
        self._db.add(prefs)

        await self._db.commit()
        await self._db.refresh(user)

        return await self._issue_tokens(user)

    async def login(self, req: LoginRequest) -> AuthResponse:
        user = await self._db.scalar(
            select(User).where(User.email == req.email.lower())
        )
        if not user or not verify_password(req.password, user.password_hash):
            raise InvalidCredentialsError()
        if not user.is_active:
            raise InvalidCredentialsError("Account is inactive.")

        return await self._issue_tokens(user)

    async def refresh(self, raw_token: str) -> AuthResponse:
        try:
            payload = decode_refresh_token(raw_token)
        except Exception as exc:
            raise InvalidTokenError(str(exc)) from exc

        token_hash = _hash_token(raw_token)
        stored = await self._db.scalar(
            select(RefreshToken).where(
                RefreshToken.token_hash == token_hash,
                RefreshToken.revoked == False,  # noqa: E712
            )
        )
        if not stored:
            raise InvalidTokenError("Refresh token not found or already revoked.")
        if stored.expires_at.replace(tzinfo=timezone.utc) < datetime.now(tz=timezone.utc):
            raise InvalidTokenError("Refresh token has expired.")

        # Rotate: revoke old, issue new
        stored.revoked = True
        await self._db.flush()

        user = await self._db.get(User, payload["sub"])
        if not user or not user.is_active:
            raise InvalidTokenError("User not found.")

        return await self._issue_tokens(user)

    async def logout(self, user_id: str) -> None:
        # Revoke all tokens for this user
        tokens = (
            await self._db.scalars(
                select(RefreshToken).where(
                    RefreshToken.user_id == user_id,
                    RefreshToken.revoked == False,  # noqa: E712
                )
            )
        ).all()
        for t in tokens:
            t.revoked = True
        await self._db.commit()

    async def login_with_google(self, req: GoogleAuthRequest) -> AuthResponse:
        """
        Verify Google identity token (ID token or Access token via UserInfo),
        find existing user or auto-provision Guardian user,
        and issue Guardian JWT access + refresh tokens.
        """
        import httpx
        from app.core.logging import get_logger
        log = get_logger("auth_service")

        log.info("[GOOGLE_AUTH] request received")
        log.info("[GOOGLE_AUTH] token verification started")

        google_user_info = None
        raw_token = req.id_token.strip()

        async with httpx.AsyncClient(timeout=10.0) as client:
            # 1. Try Google TokenInfo endpoint (for ID tokens)
            try:
                resp = await client.get(
                    f"https://oauth2.googleapis.com/tokeninfo?id_token={raw_token}"
                )
                if resp.status_code == 200:
                    google_user_info = resp.json()
                    log.info("[GOOGLE_AUTH] tokeninfo verification success")
            except Exception as e:
                log.warning("[GOOGLE_AUTH] tokeninfo network error", error=str(e))

            # 2. Fallback: Try Google UserInfo endpoint (for OAuth access tokens)
            if not google_user_info or "email" not in google_user_info:
                try:
                    userinfo_resp = await client.get(
                        "https://www.googleapis.com/oauth2/v3/userinfo",
                        headers={"Authorization": f"Bearer {raw_token}"},
                    )
                    if userinfo_resp.status_code == 200:
                        google_user_info = userinfo_resp.json()
                        log.info("[GOOGLE_AUTH] userinfo endpoint verification success")
                except Exception as e:
                    log.warning("[GOOGLE_AUTH] userinfo network error", error=str(e))

        # 3. Validate extracted user information
        if google_user_info and "email" in google_user_info:
            aud = google_user_info.get("aud")
            azp = google_user_info.get("azp")
            project_prefix = "638591615239"

            if settings.google_client_id and aud:
                # Accept exact web client ID, matching project ID prefix, or matching authorized party
                is_valid_aud = (
                    aud == settings.google_client_id
                    or aud.startswith(project_prefix)
                    or (azp and azp.startswith(project_prefix))
                    or settings.app_debug
                )
                if not is_valid_aud:
                    log.warning(
                        "[GOOGLE_AUTH] token audience mismatch",
                        expected=settings.google_client_id,
                        received_aud=aud,
                        received_azp=azp,
                    )
                    raise InvalidCredentialsError("Invalid token audience.")
        else:
            # Development/Testing fallback for mock token strings
            if (settings.app_env in ("development", "test") or settings.app_debug) and "mock" in raw_token.lower():
                mock_email = "google_user@guardian.ai"
                if "@" in raw_token:
                    mock_email = raw_token.split("_")[-1]
                google_user_info = {
                    "email": mock_email,
                    "name": "Google Guardian User",
                    "sub": f"google_{hashlib.md5(mock_email.encode()).hexdigest()[:12]}",
                    "picture": "",
                }
                log.info("[GOOGLE_AUTH] test mock token accepted")
            else:
                log.warning("[GOOGLE_AUTH] token verification failed — invalid credentials")
                raise InvalidCredentialsError("Invalid or expired Google identity token.")

        email = google_user_info["email"].lower()
        full_name = google_user_info.get("name") or email.split("@")[0].title()
        picture = google_user_info.get("picture")

        # Find existing user
        user = await self._db.scalar(
            select(User).where(User.email == email)
        )
        if not user:
            log.info("[GOOGLE_AUTH] user lookup result = new user auto-provisioned")
            # Auto-provision user
            user = User(
                email=email,
                password_hash=hash_password(f"google_oauth_{google_user_info.get('sub', email)}"),
                full_name=full_name,
                phone=None,
            )
            self._db.add(user)
            await self._db.flush()

            # Create profile
            profile = UserProfile(user_id=user.id, avatar_url=picture or "")
            self._db.add(profile)

            # Create default preferences
            prefs = UserPreference(user_id=user.id)
            self._db.add(prefs)

            await self._db.commit()
            await self._db.refresh(user)
        else:
            if not user.is_active:
                raise InvalidCredentialsError("Account is inactive.")
            if picture:
                profile = await self._db.scalar(
                    select(UserProfile).where(UserProfile.user_id == user.id)
                )
                if profile and not profile.avatar_url:
                    profile.avatar_url = picture
                    await self._db.commit()

        return await self._issue_tokens(user)

    async def forgot_password(self, email: str) -> None:
        """
        In production: generate a reset token, email it.
        For now, we acknowledge the request without leaking whether the email exists.
        """
        # TODO: integrate email provider + reset token storage
        pass

    async def _issue_tokens(self, user: User) -> AuthResponse:
        access_token = create_access_token(user.id)
        refresh_token = create_refresh_token(user.id)

        expires_at = datetime.now(tz=timezone.utc) + timedelta(
            days=settings.jwt_refresh_expire_days
        )
        stored = RefreshToken(
            user_id=user.id,
            token_hash=_hash_token(refresh_token),
            expires_at=expires_at,
        )
        self._db.add(stored)
        await self._db.commit()

        return AuthResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            user_id=user.id,
        )
