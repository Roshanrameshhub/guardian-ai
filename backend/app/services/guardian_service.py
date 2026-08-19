from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import BadRequestError, ForbiddenError, NotFoundError
from app.models.guardian import GuardianSession, GuardianSessionStatus
from app.models.user import User, UserProfile
from app.schemas.guardian import GuardianStatusResponse, HeartbeatRequest, LocationUpdateRequest

settings = get_settings()

DEFAULT_AVATAR = "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&h=200&fit=crop"


def session_to_response(session: GuardianSession, user: User, profile: UserProfile | None) -> GuardianStatusResponse:
    is_active = session.status == GuardianSessionStatus.active
    return GuardianStatusResponse(
        is_active=is_active,
        status_label="ACTIVE" if is_active else "INACTIVE",
        monitoring_label="AI-Enhanced Monitoring Active" if is_active else "Guardian paused",
        voice_sync_live=is_active,
        voice_sync_state="Listening" if is_active else "Idle",
        battery_percent=session.battery_percent or 100,
        speed_kmh=session.speed_kmh or 0.0,
        speed_status=_speed_label(session.speed_kmh or 0.0),
        estimated_arrival=session.estimated_arrival or "--:--",
        minutes_left=session.minutes_left or 0,
        origin=session.origin or "",
        destination=session.destination or "",
        progress=session.progress,
        current_location=session.current_location_name or session.origin or "",
        avatar_url=(profile.avatar_url if profile and profile.avatar_url else DEFAULT_AVATAR),
        session_id=session.id,
    )


def _speed_label(kmh: float) -> str:
    if kmh < 0.5:
        return "Stationary"
    if kmh < 8:
        return "Walking"
    if kmh < 25:
        return "Cycling"
    return "Driving"


class GuardianService:
    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def get_status(self, user_id: str) -> GuardianStatusResponse:
        """Return the active session or an inactive stub."""
        user = await self._db.get(User, user_id)
        if not user:
            raise NotFoundError("User not found.")
        profile = await self._db.scalar(
            select(UserProfile).where(UserProfile.user_id == user_id)
        )

        session = await self._get_active_session(user_id)
        if session is None:
            return GuardianStatusResponse(
                is_active=False,
                status_label="INACTIVE",
                monitoring_label="Guardian inactive",
                voice_sync_live=False,
                voice_sync_state="Idle",
                battery_percent=100,
                speed_kmh=0.0,
                speed_status="Stationary",
                estimated_arrival="--:--",
                minutes_left=0,
                origin="",
                destination="",
                progress=0.0,
                current_location="",
                avatar_url=(profile.avatar_url if profile and profile.avatar_url else DEFAULT_AVATAR),
            )
        return session_to_response(session, user, profile)

    async def start(self, user_id: str, origin: str = "", destination: str = "") -> GuardianStatusResponse:
        # Stop any existing active sessions first
        existing = await self._get_active_session(user_id)
        if existing:
            existing.status = GuardianSessionStatus.stopped
            existing.ended_at = datetime.now(tz=timezone.utc)
            await self._db.flush()

        session = GuardianSession(
            user_id=user_id,
            status=GuardianSessionStatus.active,
            origin=origin or "Current Location",
            destination=destination or "Destination",
            last_heartbeat=datetime.now(tz=timezone.utc),
        )
        self._db.add(session)
        await self._db.commit()
        await self._db.refresh(session)

        user = await self._db.get(User, user_id)
        profile = await self._db.scalar(
            select(UserProfile).where(UserProfile.user_id == user_id)
        )
        # Activate safety shield
        if profile:
            profile.safety_shield_active = True
            await self._db.commit()

        return session_to_response(session, user, profile)

    async def stop(self, user_id: str) -> GuardianStatusResponse:
        session = await self._get_active_session(user_id)
        if not session:
            raise BadRequestError("No active Guardian session to stop.")

        session.status = GuardianSessionStatus.stopped
        session.ended_at = datetime.now(tz=timezone.utc)

        user = await self._db.get(User, user_id)
        profile = await self._db.scalar(
            select(UserProfile).where(UserProfile.user_id == user_id)
        )
        if profile:
            profile.safety_shield_active = False

        await self._db.commit()
        await self._db.refresh(session)
        return session_to_response(session, user, profile)

    async def heartbeat(
        self, user_id: str, session_id: str, req: HeartbeatRequest
    ) -> GuardianStatusResponse:
        session = await self._db.get(GuardianSession, session_id)
        if not session or session.user_id != user_id:
            raise NotFoundError("Guardian session not found.")
        if session.status != GuardianSessionStatus.active:
            raise BadRequestError("Guardian session is not active.")

        now = datetime.now(tz=timezone.utc)
        session.last_heartbeat = now
        if req.lat is not None:
            session.current_lat = req.lat
        if req.lng is not None:
            session.current_lng = req.lng
        if req.battery_percent is not None:
            session.battery_percent = req.battery_percent
        if req.speed_kmh is not None:
            session.speed_kmh = req.speed_kmh

        await self._db.commit()
        await self._db.refresh(session)

        user = await self._db.get(User, user_id)
        profile = await self._db.scalar(
            select(UserProfile).where(UserProfile.user_id == user_id)
        )
        return session_to_response(session, user, profile)

    async def update_location(
        self, user_id: str, session_id: str, req: LocationUpdateRequest
    ) -> GuardianStatusResponse:
        session = await self._db.get(GuardianSession, session_id)
        if not session or session.user_id != user_id:
            raise NotFoundError("Guardian session not found.")

        session.current_lat = req.lat
        session.current_lng = req.lng
        session.last_heartbeat = datetime.now(tz=timezone.utc)
        if req.speed_kmh is not None:
            session.speed_kmh = req.speed_kmh
        if req.battery_percent is not None:
            session.battery_percent = req.battery_percent

        # Record location in journey if linked
        if session.journey_id:
            from app.models.journey import JourneyLocation
            loc = JourneyLocation(
                journey_id=session.journey_id,
                lat=req.lat,
                lng=req.lng,
                accuracy_m=req.accuracy_m,
                speed_kmh=req.speed_kmh,
            )
            self._db.add(loc)

        await self._db.commit()
        await self._db.refresh(session)

        user = await self._db.get(User, user_id)
        profile = await self._db.scalar(
            select(UserProfile).where(UserProfile.user_id == user_id)
        )
        return session_to_response(session, user, profile)

    async def _get_active_session(self, user_id: str) -> GuardianSession | None:
        return await self._db.scalar(
            select(GuardianSession).where(
                GuardianSession.user_id == user_id,
                GuardianSession.status == GuardianSessionStatus.active,
            )
        )
