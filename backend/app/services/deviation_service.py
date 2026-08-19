from __future__ import annotations

import math
from typing import List
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.journey import Journey, JourneyEvent, JourneyEventType
from app.models.intelligence import DeviationSeverity
from app.schemas.intelligence import (
    RouteDeviationCheckRequest,
    RouteDeviationCheckResponse,
)
from app.services.safe_arrival_service import _haversine_distance_meters


def _min_distance_to_route_meters(
    lat: float, lng: float, route_points: List[dict[str, float]]
) -> float:
    """Calculate the minimum distance from current point to any vertex on the route polyline."""
    if not route_points:
        return 0.0

    min_dist = float("inf")
    for pt in route_points:
        d = _haversine_distance_meters(lat, lng, pt["lat"], pt["lng"])
        if d < min_dist:
            min_dist = d
    return min_dist


class DeviationService:
    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def evaluate_deviation(
        self, user_id: str, req: RouteDeviationCheckRequest
    ) -> RouteDeviationCheckResponse:
        journey = await self._db.get(Journey, req.journey_id)
        if not journey or journey.user_id != user_id:
            return RouteDeviationCheckResponse(
                journey_id=req.journey_id,
                deviation_status="NORMAL",
                cross_track_distance_meters=0.0,
                deviation_risk_score=0.0,
                message="Journey not found.",
            )

        # Calculate cross-track distance
        min_dist = _min_distance_to_route_meters(
            req.current_lat, req.current_lng, req.route_points
        )

        # Deviation Tiers
        if min_dist > 500:
            status = DeviationSeverity.confirmed
            risk_score = 0.85
            msg = f"Confirmed route deviation ({int(min_dist)}m off planned route corridor)."
        elif min_dist > 250:
            status = DeviationSeverity.significant
            risk_score = 0.65
            msg = f"Significant route deviation ({int(min_dist)}m off planned corridor)."
        elif min_dist > 100:
            status = DeviationSeverity.minor
            risk_score = 0.35
            msg = f"Minor route variance ({int(min_dist)}m off planned corridor)."
        else:
            status = DeviationSeverity.normal
            risk_score = 0.0
            msg = "Position is on planned route corridor."

        # If significant deviation, record journey event
        if status in (DeviationSeverity.significant, DeviationSeverity.confirmed):
            event = JourneyEvent(
                journey_id=journey.id,
                event_type=JourneyEventType.deviation,
                title="Route Deviation Warning",
                subtitle=f"{int(min_dist)}m deviation detected from scheduled path",
                lat=req.current_lat,
                lng=req.current_lng,
            )
            self._db.add(event)
            await self._db.commit()

        return RouteDeviationCheckResponse(
            journey_id=journey.id,
            deviation_status=status.value.upper(),
            cross_track_distance_meters=round(min_dist, 1),
            deviation_risk_score=risk_score,
            message=msg,
        )
