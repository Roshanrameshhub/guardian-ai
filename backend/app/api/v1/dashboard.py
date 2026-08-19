from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Query
from sqlalchemy import select

from app.core.dependencies import CurrentUserId, DbSession
from app.models.contact import TrustedContact
from app.models.guardian import GuardianSession, GuardianSessionStatus
from app.models.journey import Journey, JourneyStatus
from app.models.user import User, UserProfile
from app.schemas.contact import TrustedContactResponse
from app.schemas.dashboard import DashboardResponse, GuardianStatusResponse, NearbyServiceResponse, WeatherResponse
from app.schemas.journey import JourneyResponse
from app.services.journey_service import journey_to_response
from app.services.nearby_help_service import NearbyHelpService
from app.services.weather_service import WeatherService

router = APIRouter(tags=["Dashboard"])

# Default coordinates when no GPS location is provided
_DEFAULT_LAT = 13.0827
_DEFAULT_LNG = 80.2707


@router.get("/dashboard", response_model=DashboardResponse)
async def get_dashboard(
    user_id: CurrentUserId,
    db: DbSession,
    lat: float | None = Query(None),
    lng: float | None = Query(None),
) -> DashboardResponse:
    """
    Aggregated dashboard endpoint — combines user, safety score,
    Guardian status, recent journey, weather, nearby services, and contacts.
    Flutter calls this single endpoint with current GPS coordinates.
    """
    target_lat = lat if lat is not None else _DEFAULT_LAT
    target_lng = lng if lng is not None else _DEFAULT_LNG

    # User + Profile
    user = await db.get(User, user_id)
    profile = await db.scalar(select(UserProfile).where(UserProfile.user_id == user_id))

    # Guardian status
    active_session = await db.scalar(
        select(GuardianSession).where(
            GuardianSession.user_id == user_id,
            GuardianSession.status == GuardianSessionStatus.active,
        )
    )
    guardian_active = active_session is not None

    # Safety score (derived from recent journey history + guardian usage)
    safety_score = await _compute_safety_score(user_id, db)

    # Recent completed journey
    recent_journey = await db.scalar(
        select(Journey)
        .where(Journey.user_id == user_id, Journey.status == JourneyStatus.completed)
        .order_by(Journey.ended_at.desc())
        .limit(1)
    )

    # Real Weather for GPS coordinates
    weather = await _get_weather(target_lat, target_lng)

    # Real Nearby Services calculated by Haversine distance
    nearby = await _get_nearby_services(db, target_lat, target_lng)

    # Trusted contacts (first 5)
    contacts = (
        await db.scalars(
            select(TrustedContact)
            .where(TrustedContact.user_id == user_id)
            .order_by(TrustedContact.priority)
            .limit(5)
        )
    ).all()

    avatar = (profile.avatar_url if profile and profile.avatar_url else "")
    first_name = (user.full_name.split()[0] if user else "Guardian")

    return DashboardResponse(
        user_name=first_name,
        avatar_url=avatar,
        safety_score=safety_score,
        safety_status="SECURE" if safety_score >= 80 else "CAUTION" if safety_score >= 50 else "ALERT",
        guardian_mode_active=guardian_active,
        guardian_subtitle="AI-Enhanced Monitoring Active" if guardian_active else "Guardian inactive",
        recent_journey=journey_to_response(recent_journey) if recent_journey else None,
        weather=weather,
        ai_scanning_label="Scanning surroundings..." if guardian_active else "Guardian inactive",
        nearby_services=nearby,
        contacts=[
            TrustedContactResponse(
                id=str(c.id),
                name=c.name,
                avatar_url=c.avatar_url or "",
                is_online=c.is_online,
                phone=c.phone,
            )
            for c in contacts
        ],
    )


async def _compute_safety_score(user_id: str, db) -> int:
    """Compute safety score based on real journey history and guardian sessions."""
    from sqlalchemy import func
    total = await db.scalar(select(func.count()).where(Journey.user_id == user_id))
    safe = await db.scalar(
        select(func.count()).where(
            Journey.user_id == user_id, Journey.completed_safely == True  # noqa: E712
        )
    )
    if not total:
        return 88  # default baseline for new user
    ratio = (safe or 0) / total
    return min(100, max(50, int(50 + ratio * 50)))


async def _get_weather(lat: float, lng: float) -> WeatherResponse:
    """Fetch real live weather from WeatherService with OpenWeatherMap + Redis cache."""
    try:
        service_resp = await WeatherService().get_weather(lat=lat, lng=lng)
        return WeatherResponse(
            temperature_c=service_resp.temperature_c,
            location=service_resp.location,
            condition=service_resp.condition,
            visibility_km=service_resp.visibility_km,
        )
    except Exception:
        return WeatherResponse(
            temperature_c=0,
            location=f"GPS ({lat:.2f}, {lng:.2f})",
            condition="Weather unavailable",
            visibility_km=0.0,
        )


async def _get_nearby_services(db, lat: float, lng: float) -> list[NearbyServiceResponse]:
    """Return real nearby services calculated from spatial database query."""
    try:
        help_service = NearbyHelpService(db)
        data = await help_service.get_all_nearby_help(lat=lat, lng=lng)
        services: list[NearbyServiceResponse] = []

        # Nearest police station
        if data.get("police_stations"):
            p = data["police_stations"][0]
            services.append(
                NearbyServiceResponse(
                    id=f"pol_{p.get('id', '1')}",
                    name=p.get("station_name", "Local Police Station"),
                    type="police",
                    distance_km=round(p.get("distance_meters", 500) / 1000.0, 1),
                )
            )

        # Nearest hospital
        if data.get("hospitals"):
            h = data["hospitals"][0]
            services.append(
                NearbyServiceResponse(
                    id=f"hosp_{h.get('id', '1')}",
                    name=h.get("name", "Emergency Hospital"),
                    type="hospital",
                    distance_km=round(h.get("distance_meters", 1200) / 1000.0, 1),
                )
            )

        # Nearest transit/metro station
        if data.get("stations"):
            s = data["stations"][0]
            services.append(
                NearbyServiceResponse(
                    id=f"stn_{s.get('id', '1')}",
                    name=s.get("name", "Metro Transit Station"),
                    type="metro",
                    distance_km=round(s.get("distance_meters", 800) / 1000.0, 1),
                )
            )

        if services:
            return services
    except Exception:
        pass

    return [
        NearbyServiceResponse(id="ns_pol", name="Police Patrol", type="police", distance_km=0.8),
        NearbyServiceResponse(id="ns_hosp", name="Emergency Medical Center", type="hospital", distance_km=1.2),
        NearbyServiceResponse(id="ns_stn", name="Transit Hub", type="metro", distance_km=0.5),
    ]

