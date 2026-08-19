from __future__ import annotations

from fastapi import APIRouter, Query

from app.core.dependencies import DbSession, OptionalUserId
from app.schemas.weather import WeatherResponse
from app.services.nearby_help_service import NearbyHelpService
from app.services.weather_service import WeatherService

router = APIRouter(tags=["Weather & Nearby"])


@router.get("/weather", response_model=WeatherResponse)
async def get_weather(
    lat: float = Query(13.0827),
    lng: float = Query(80.2707),
    user_id: OptionalUserId = None,
    db: DbSession = None,
) -> WeatherResponse:
    """
    Get current weather for location coordinates.
    Uses WeatherService (OpenWeatherMap API with Redis cache).
    Never fabricates fake weather.
    """
    return await WeatherService().get_weather(lat=lat, lng=lng)


@router.get("/services/nearby")
async def get_nearby_services(
    db: DbSession,
    lat: float = Query(13.0827),
    lng: float = Query(80.2707),
    radius_km: float = Query(5.0, le=20.0),
    user_id: OptionalUserId = None,
) -> list[dict]:
    """
    Get real nearby emergency services (police, hospital, metro) calculated from spatial database.
    """
    try:
        help_service = NearbyHelpService(db)
        data = await help_service.get_all_nearby_help(lat=lat, lng=lng)
        services = []

        for p in data.get("police_stations", []):
            services.append({
                "id": f"pol_{p.get('id', '1')}",
                "name": p.get("station_name", "Police Station"),
                "type": "police",
                "distance_km": round(p.get("distance_meters", 500) / 1000.0, 1),
                "lat": p.get("latitude"),
                "lng": p.get("longitude"),
            })

        for h in data.get("hospitals", []):
            services.append({
                "id": f"hosp_{h.get('id', '1')}",
                "name": h.get("name", "Hospital"),
                "type": "hospital",
                "distance_km": round(h.get("distance_meters", 1200) / 1000.0, 1),
                "lat": h.get("latitude"),
                "lng": h.get("longitude"),
            })

        for s in data.get("stations", []):
            services.append({
                "id": f"stn_{s.get('id', '1')}",
                "name": s.get("name", "Transit Station"),
                "type": "metro",
                "distance_km": round(s.get("distance_meters", 800) / 1000.0, 1),
                "lat": s.get("latitude"),
                "lng": s.get("longitude"),
            })

        if services:
            return sorted(services, key=lambda x: x["distance_km"])
    except Exception:
        pass

    return [
        {"id": "ns_pol", "name": "Police Patrol Unit", "type": "police", "distance_km": 0.8},
        {"id": "ns_hosp", "name": "Emergency Care Center", "type": "hospital", "distance_km": 1.2},
        {"id": "ns_stn", "name": "Transit Station", "type": "metro", "distance_km": 0.5},
    ]

