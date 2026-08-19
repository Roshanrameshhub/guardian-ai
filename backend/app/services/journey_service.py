from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import ForbiddenError, NotFoundError
from app.models.journey import Journey, JourneyEvent, JourneyEventType, JourneyStatus
from app.schemas.journey import (
    JourneyResponse,
    RerouteRequest,
    StartJourneyRequest,
    StationaryCheckRequest,
    StationaryCheckResponse,
)


def _format_date_label(dt: datetime) -> str:
    now = datetime.now(tz=timezone.utc)
    diff = (now.date() - dt.date()).days
    if diff == 0:
        return "Today"
    if diff == 1:
        return "Yesterday"
    return dt.strftime("%b %d")


def _format_time_range(started: datetime, ended: datetime | None) -> str:
    start_str = started.strftime("%I:%M %p").lstrip("0") if hasattr(started, "strftime") else ""
    if ended and hasattr(ended, "strftime"):
        return f"{start_str} - {ended.strftime('%I:%M %p').lstrip('0')}"
    return f"{start_str} - Ongoing"


def journey_to_response(j: Journey) -> JourneyResponse:
    started = j.started_at or j.created_at
    return JourneyResponse(
        id=j.id,
        title=j.title,
        subtitle=f"{_format_date_label(started)} • {_format_time_range(started, j.ended_at)}",
        from_=j.origin,
        to=j.destination,
        date_label=_format_date_label(started),
        time_range=_format_time_range(started, j.ended_at),
        safety_score=j.safety_score or 0.0,
        is_alert=j.is_alert,
        completed_safely=j.completed_safely,
        status=j.status.value if j.status else None,
    )


class JourneyService:
    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def list_journeys(self, user_id: str, limit: int = 20) -> list[Journey]:
        result = await self._db.scalars(
            select(Journey)
            .where(Journey.user_id == user_id)
            .order_by(Journey.created_at.desc())
            .limit(limit)
        )
        return list(result.all())

    async def get_journey(self, user_id: str, journey_id: str) -> Journey:
        journey = await self._db.get(Journey, journey_id)
        if not journey:
            raise NotFoundError("Journey not found.")
        if journey.user_id != user_id:
            raise ForbiddenError()
        return journey

    async def start_journey(self, user_id: str, req: StartJourneyRequest) -> Journey:
        now = datetime.now(tz=timezone.utc)

        # Safely complete any previous dangling active journeys for this user
        existing_active = await self._db.scalars(
            select(Journey).where(
                Journey.user_id == user_id,
                Journey.status == JourneyStatus.active,
            )
        )
        for old_j in existing_active.all():
            old_j.status = JourneyStatus.completed
            old_j.ended_at = now
            old_j.completed_safely = True

        title = f"Trip from {req.origin} to {req.destination}"
        journey = Journey(
            user_id=user_id,
            title=title,
            origin=req.origin,
            destination=req.destination,
            origin_lat=req.origin_lat,
            origin_lng=req.origin_lng,
            dest_lat=req.dest_lat,
            dest_lng=req.dest_lng,
            status=JourneyStatus.active,
            started_at=now,
            safety_score=8.8,
        )
        self._db.add(journey)
        await self._db.flush()


        # Record start event
        event = JourneyEvent(
            journey_id=journey.id,
            event_type=JourneyEventType.started,
            title=f"Journey started from {req.origin}",
            subtitle=f"Destination: {req.destination}",
        )
        self._db.add(event)
        await self._db.commit()
        await self._db.refresh(journey)
        return journey

    async def stop_journey(self, user_id: str, journey_id: str) -> Journey:
        journey = await self.get_journey(user_id, journey_id)
        now = datetime.now(tz=timezone.utc)
        journey.status = JourneyStatus.completed
        journey.ended_at = now
        journey.completed_safely = True

        # Record completion event
        event = JourneyEvent(
            journey_id=journey.id,
            event_type=JourneyEventType.completed,
            title=f"Arrived at {journey.destination}",
            subtitle="Journey completed safely",
        )
        self._db.add(event)

        # Increment safe_trips on profile
        from app.models.user import UserProfile
        profile = await self._db.scalar(
            select(UserProfile).where(UserProfile.user_id == user_id)
        )
        if profile:
            profile.safe_trips += 1

        await self._db.commit()
        await self._db.refresh(journey)
        return journey

    async def delete_journey(self, user_id: str, journey_id: str) -> None:
        journey = await self.get_journey(user_id, journey_id)
        await self._db.delete(journey)
        await self._db.commit()

    async def check_stationary(
        self, user_id: str, req: StationaryCheckRequest
    ) -> StationaryCheckResponse:
        from app.core.config import get_settings
        from app.services.safe_arrival_service import _haversine_distance_meters
        settings = get_settings()

        journey = await self.get_journey(user_id, req.journey_id)

        # Check if destination reached
        dest_lat = req.destination_lat or journey.dest_lat
        dest_lng = req.destination_lng or journey.dest_lng
        if dest_lat is not None and dest_lng is not None:
            dist_to_dest = _haversine_distance_meters(
                req.current_lat, req.current_lng, dest_lat, dest_lng
            )
            if dist_to_dest < 120.0:
                return StationaryCheckResponse(
                    journey_id=journey.id,
                    is_stationary=True,
                    is_traffic_delay=False,
                    alert_level="NONE",
                    message="At or near destination. Journey completion ready.",
                    requires_prompt=False,
                )

        # Evaluate speed & stationary status
        is_stationary = req.speed_kmh < 4.0
        is_traffic_delay = False
        alert_level = "NONE"
        requires_prompt = False
        message = "Movement normal along planned route."

        if is_stationary:
            # Check if traffic explains the delay
            if req.traffic_congestion_level.upper() in ("HEAVY", "SEVERE"):
                is_traffic_delay = True
                message = "Slow traffic detected along corridor. Normal progress delay."
                alert_level = "NONE"
                requires_prompt = False
            else:
                warn_mins = settings.journey_stationary_warning_minutes
                crit_mins = settings.journey_stationary_critical_minutes

                if req.stationary_minutes >= crit_mins:
                    alert_level = "LEVEL_3_ASSISTANCE"
                    requires_prompt = True
                    message = f"Guardian noticed an unexpected prolonged stop ({req.stationary_minutes} min). Need assistance?"
                elif req.stationary_minutes >= warn_mins:
                    alert_level = "LEVEL_1_CHECKIN"
                    requires_prompt = True
                    message = f"You appear to have stopped for {req.stationary_minutes} minutes. Everything okay?"
                else:
                    message = "Brief stationary pause detected."
                    alert_level = "NONE"

        return StationaryCheckResponse(
            journey_id=journey.id,
            is_stationary=is_stationary,
            is_traffic_delay=is_traffic_delay,
            alert_level=alert_level,
            message=message,
            requires_prompt=requires_prompt,
        )

    async def calculate_reroute(
        self, user_id: str, req: RerouteRequest
    ) -> dict:
        from app.services.guardian_safety_engine import GuardianSafetyEngine
        engine = GuardianSafetyEngine(self._db)

        # Calculate safety-aware reroute using existing engine
        plan = await engine.calculate_safe_routes(
            origin_lat=req.current_lat,
            origin_lng=req.current_lng,
            dest_lat=req.destination_lat,
            dest_lng=req.destination_lng,
            destination_name=req.destination_name,
            travel_mode=req.travel_mode,
        )

        # Record reroute event in journey
        event = JourneyEvent(
            journey_id=req.journey_id,
            event_type=JourneyEventType.deviation,
            title="Safety Reroute Applied",
            subtitle=f"Safety score {plan.get('safety_score', 80)}/100 • {plan.get('reason', '')}",
            lat=req.current_lat,
            lng=req.current_lng,
        )
        self._db.add(event)
        await self._db.commit()

        return plan
