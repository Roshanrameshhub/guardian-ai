from __future__ import annotations

import math
from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.journey import Journey, JourneyEvent, JourneyEventType, JourneyStatus
from app.schemas.intelligence import SafeArrivalCheckRequest, SafeArrivalCheckResponse


def _haversine_distance_meters(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate distance in meters between two lat/lon coordinates."""
    r = 6371000  # Earth radius in meters
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = (
        math.sin(delta_phi / 2.0) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2.0) ** 2
    )
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return r * c


class SafeArrivalService:
    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def check_arrival(
        self, user_id: str, req: SafeArrivalCheckRequest
    ) -> SafeArrivalCheckResponse:
        journey = await self._db.get(Journey, req.journey_id)
        if not journey or journey.user_id != user_id:
            return SafeArrivalCheckResponse(
                journey_id=req.journey_id,
                arrived=False,
                distance_meters=-1.0,
                message="Journey not found.",
            )

        if journey.dest_lat is None or journey.dest_lng is None:
            return SafeArrivalCheckResponse(
                journey_id=req.journey_id,
                arrived=False,
                distance_meters=-1.0,
                message="Destination coordinates not set for this journey.",
            )

        distance = _haversine_distance_meters(
            req.current_lat, req.current_lng, journey.dest_lat, journey.dest_lng
        )

        arrived = distance <= req.threshold_meters

        if arrived and journey.status == JourneyStatus.active:
            journey.completed_safely = True
            journey.status = JourneyStatus.completed
            journey.ended_at = datetime.now(tz=timezone.utc)

            event = JourneyEvent(
                journey_id=journey.id,
                event_type=JourneyEventType.safe_arrival,
                title="Safe Arrival Detected",
                subtitle=f"Arrived within {int(distance)}m of destination {journey.destination}",
                lat=req.current_lat,
                lng=req.current_lng,
            )
            self._db.add(event)
            await self._db.commit()

        message = (
            f"Safe arrival confirmed ({int(distance)}m from destination)."
            if arrived
            else f"Currently {int(distance)}m from destination (threshold {int(req.threshold_meters)}m)."
        )

        return SafeArrivalCheckResponse(
            journey_id=journey.id,
            arrived=arrived,
            distance_meters=round(distance, 1),
            message=message,
        )
