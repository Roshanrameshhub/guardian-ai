from __future__ import annotations

from pydantic import BaseModel

from app.schemas.contact import TrustedContactResponse
from app.schemas.journey import JourneyResponse


class WeatherResponse(BaseModel):
    """Matches Flutter WeatherEntity."""
    temperature_c: int
    location: str
    condition: str
    visibility_km: float
    icon: str | None = None
    humidity: int | None = None


class NearbyServiceResponse(BaseModel):
    """Matches Flutter NearbyServiceEntity."""
    id: str
    name: str
    type: str  # metro / hospital / police
    distance_km: float


class GuardianStatusResponse(BaseModel):
    """Matches Flutter GuardianStatusEntity."""
    is_active: bool
    status_label: str
    monitoring_label: str
    voice_sync_live: bool
    voice_sync_state: str
    battery_percent: int
    speed_kmh: float
    speed_status: str
    estimated_arrival: str
    minutes_left: int
    origin: str
    destination: str
    progress: float
    current_location: str
    avatar_url: str
    session_id: str | None = None


class DashboardResponse(BaseModel):
    """Matches Flutter DashboardEntity — aggregated single endpoint."""
    user_name: str
    avatar_url: str
    safety_score: int
    safety_status: str
    guardian_mode_active: bool
    guardian_subtitle: str
    recent_journey: JourneyResponse | None
    weather: WeatherResponse
    ai_scanning_label: str
    nearby_services: list[NearbyServiceResponse]
    contacts: list[TrustedContactResponse]
