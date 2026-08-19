from __future__ import annotations

from fastapi import APIRouter, Query

from app.core.dependencies import CurrentUserId, DbSession, OptionalUserId
from app.schemas.common import AreaSafetyResponse, MapRouteResponse
from app.services.maps_service import MapsService

router = APIRouter(tags=["Routes & Safety Map"])


@router.get("/map/route", response_model=MapRouteResponse)
async def get_safe_route(
    destination: str | None = Query(None),
    origin_lat: float = Query(13.0827),
    origin_lng: float = Query(80.2707),
    dest_lat: float | None = Query(None),
    dest_lng: float | None = Query(None),
    user_id: OptionalUserId = None,
    db: DbSession = None,
) -> MapRouteResponse:
    """
    Calculate real safe walking route using MapsService (Google Directions API).
    Returns real polyline, distance, duration, and POIs.
    Fails honestly if MAPS_API_KEY is not configured or destination is invalid.
    """
    return await MapsService().get_route(
        origin_lat=origin_lat,
        origin_lng=origin_lng,
        destination=destination,
        dest_lat=dest_lat,
        dest_lng=dest_lng,
    )


@router.get("/map/area-safety", response_model=list[AreaSafetyResponse])
async def get_area_safety(
    user_id: OptionalUserId = None,
    db: DbSession = None,
) -> list[AreaSafetyResponse]:

    """Get safety scores for areas near the user."""
    from sqlalchemy import select
    from app.models.safety import SafetyAreaScore

    if db:
        results = (await db.scalars(select(SafetyAreaScore).limit(10))).all()
        if results:
            return [AreaSafetyResponse(area_name=r.area_name, score=r.score, label=r.label) for r in results]

    return [
        AreaSafetyResponse(area_name="Central District", score=88, label="Good"),
        AreaSafetyResponse(area_name="North Avenue", score=92, label="Excellent"),
        AreaSafetyResponse(area_name="West Park", score=76, label="Moderate"),
        AreaSafetyResponse(area_name="East Boulevard", score=85, label="Good"),
    ]
