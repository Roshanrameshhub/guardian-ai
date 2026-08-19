from __future__ import annotations

from pydantic import BaseModel


class StartJourneyRequest(BaseModel):
    """Matches Flutter StartJourneyRequest."""
    origin: str
    destination: str
    origin_lat: float | None = None
    origin_lng: float | None = None
    dest_lat: float | None = None
    dest_lng: float | None = None


class JourneyResponse(BaseModel):
    """Matches Flutter JourneyEntity."""
    id: str
    title: str
    subtitle: str
    from_: str
    to: str
    date_label: str
    time_range: str
    safety_score: float
    is_alert: bool
    completed_safely: bool
    status: str | None = None

    model_config = {"populate_by_name": True}


class JourneyListResponse(BaseModel):
    journeys: list[JourneyResponse]
    total: int


class StationaryCheckRequest(BaseModel):
    journey_id: str
    current_lat: float
    current_lng: float
    speed_kmh: float = 0.0
    stationary_minutes: int = 0
    traffic_congestion_level: str = "LOW"  # LOW, MODERATE, HEAVY
    destination_lat: float | None = None
    destination_lng: float | None = None


class StationaryCheckResponse(BaseModel):
    journey_id: str
    is_stationary: bool
    is_traffic_delay: bool
    alert_level: str  # NONE, LEVEL_1_CHECKIN, LEVEL_2_ALERT, LEVEL_3_ASSISTANCE
    message: str
    requires_prompt: bool


class RerouteRequest(BaseModel):
    journey_id: str
    current_lat: float
    current_lng: float
    destination_lat: float
    destination_lng: float
    destination_name: str = "Destination"
    travel_mode: str = "DRIVE"

