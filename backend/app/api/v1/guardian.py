from __future__ import annotations

from datetime import datetime
from fastapi import APIRouter, Query
from sqlalchemy import select

from app.core.dependencies import CurrentUserId, OptionalUserId, DbSession
from app.models.safety import SafetyZone, PoliceStation
from app.schemas.guardian import (
    GuardianStatusResponse,
    HeartbeatRequest,
    LocationUpdateRequest,
    GuardianRouteRequest,
    GuardianRouteResponse,
    SafetyZoneResponse,
    PoliceStationResponse,
    NearbyHelpResponse,
)
from app.services.guardian_service import GuardianService
from app.services.guardian_safety_engine import GuardianSafetyEngine
from app.services.nearby_help_service import NearbyHelpService

router = APIRouter(tags=["Guardian"])


@router.get("/guardian/status", response_model=GuardianStatusResponse)
async def get_guardian_status(
    user_id: CurrentUserId, db: DbSession
) -> GuardianStatusResponse:
    """Get current Guardian Mode status."""
    return await GuardianService(db).get_status(user_id)


@router.post("/guardian/start", response_model=GuardianStatusResponse, status_code=201)
async def start_guardian(
    user_id: CurrentUserId, db: DbSession
) -> GuardianStatusResponse:
    """Activate Guardian Mode for the current user."""
    return await GuardianService(db).start(user_id)


@router.post("/guardian/stop", response_model=GuardianStatusResponse)
async def stop_guardian(
    user_id: CurrentUserId, db: DbSession
) -> GuardianStatusResponse:
    """Deactivate Guardian Mode."""
    return await GuardianService(db).stop(user_id)


@router.post("/guardian/{session_id}/heartbeat", response_model=GuardianStatusResponse)
async def guardian_heartbeat(
    session_id: str,
    req: HeartbeatRequest,
    user_id: CurrentUserId,
    db: DbSession,
) -> GuardianStatusResponse:
    """
    Periodic heartbeat from the Flutter app.
    Must be called every 30 seconds while Guardian Mode is active.
    If heartbeats stop, the watchdog will escalate after the grace period.
    """
    return await GuardianService(db).heartbeat(user_id, session_id, req)


@router.post("/guardian/{session_id}/location", response_model=GuardianStatusResponse)
async def update_guardian_location(
    session_id: str,
    req: LocationUpdateRequest,
    user_id: CurrentUserId,
    db: DbSession,
) -> GuardianStatusResponse:
    """Update live location for an active Guardian session."""
    return await GuardianService(db).update_location(user_id, session_id, req)


@router.post("/guardian/route", response_model=GuardianRouteResponse)
async def calculate_guardian_safe_route(
    req: GuardianRouteRequest,
    db: DbSession,
    user_id: OptionalUserId = None,
) -> GuardianRouteResponse:
    """
    Calculate and evaluate safe route alternatives against the Chennai Safety Zones dataset.
    Considers Day vs Night risk factors, footfall, lighting, isolation, traffic, and travel time.
    Recommends the safest practical route.
    """
    engine = GuardianSafetyEngine(db)

    dest_lat = req.destination.latitude if hasattr(req.destination, "latitude") and req.destination.latitude is not None else 13.0456
    dest_lng = req.destination.longitude if hasattr(req.destination, "longitude") and req.destination.longitude is not None else 80.2801
    dest_name = getattr(req.destination, "name", None) or getattr(req.destination, "address", None) or "Destination"

    dep_time = None
    if req.departure_time:
        try:
            dep_time = datetime.fromisoformat(req.departure_time.replace("Z", "+00:00"))
        except Exception:
            dep_time = None

    result = await engine.calculate_safe_routes(
        origin_lat=req.origin.latitude,
        origin_lng=req.origin.longitude,
        dest_lat=dest_lat,
        dest_lng=dest_lng,
        travel_mode=req.travel_mode,
        departure_dt=dep_time,
        destination_name=dest_name,
    )
    return GuardianRouteResponse(**result)


@router.get("/guardian/safety-zones", response_model=list[SafetyZoneResponse])
async def get_safety_zones(
    db: DbSession,
    user_id: OptionalUserId = None,
) -> list[SafetyZoneResponse]:
    """
    Retrieve all Chennai safety zones for map polygon/circle rendering and informational popup details.
    NOTE: Prototype/demo data only.
    """
    result = await db.scalars(select(SafetyZone).order_by(SafetyZone.id))
    zones = result.all()
    return [
        SafetyZoneResponse(
            id=z.id,
            place=z.place,
            category=z.category,
            anchor_area=z.anchor_area,
            demo_safety_label=z.demo_safety_label,
            day_risk_score=z.day_risk_score,
            night_risk_score=z.night_risk_score,
            route_risk_score=z.route_risk_score,
            footfall=z.footfall,
            night_activity=z.night_activity,
            lighting=z.lighting,
            isolation=z.isolation,
            recommendation=z.recommendation,
            demo_safety_score=z.demo_safety_score,
            latitude=z.latitude,
            longitude=z.longitude,
            radius_meters=z.radius_meters,
            data_status=z.data_status,
            source_basis=z.source_basis,
            disclaimer="Prototype/demo data — not official crime statistics.",
        )
        for z in zones
    ]


@router.get("/guardian/police-stations", response_model=list[PoliceStationResponse])
async def get_police_stations(
    db: DbSession,
    lat: float = Query(13.0827),
    lng: float = Query(80.2707),
    limit: int = Query(10, le=50),
    user_id: OptionalUserId = None,
) -> list[PoliceStationResponse]:
    """
    Retrieve official Chennai police stations near the specified coordinates.
    """
    help_service = NearbyHelpService(db)
    stations = await help_service.get_nearby_police_stations(lat=lat, lng=lng, limit=limit)
    return [PoliceStationResponse(**st) for st in stations]


@router.get("/guardian/nearby-help", response_model=NearbyHelpResponse)
async def get_nearby_help(
    db: DbSession,
    lat: float = Query(13.0827),
    lng: float = Query(80.2707),
    user_id: OptionalUserId = None,
) -> NearbyHelpResponse:
    """
    Retrieve consolidated nearby help (Police, Hospitals, Railway/Metro, and Active Areas).
    """
    help_service = NearbyHelpService(db)
    data = await help_service.get_all_nearby_help(lat=lat, lng=lng)
    return NearbyHelpResponse(**data)

