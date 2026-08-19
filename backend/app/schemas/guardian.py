from __future__ import annotations

from pydantic import BaseModel


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


class HeartbeatRequest(BaseModel):
    lat: float | None = None
    lng: float | None = None
    battery_percent: int | None = None
    speed_kmh: float | None = None


class LocationUpdateRequest(BaseModel):
    lat: float
    lng: float
    accuracy_m: float | None = None
    speed_kmh: float | None = None
    battery_percent: int | None = None


class LatLngPoint(BaseModel):
    latitude: float
    longitude: float


class DestinationInput(BaseModel):
    latitude: float | None = None
    longitude: float | None = None
    name: str | None = None
    address: str | None = None


class GuardianRouteRequest(BaseModel):
    origin: LatLngPoint
    destination: DestinationInput | LatLngPoint
    travel_mode: str = "DRIVE"
    departure_time: str | None = None


class SafetyZoneResponse(BaseModel):
    id: str
    place: str
    category: str
    anchor_area: str
    demo_safety_label: str
    day_risk_score: int
    night_risk_score: int
    route_risk_score: int
    footfall: str
    night_activity: str
    lighting: str
    isolation: str
    recommendation: str
    demo_safety_score: int
    latitude: float
    longitude: float
    radius_meters: float
    data_status: str
    source_basis: str
    disclaimer: str = "Prototype/demo data — not official crime statistics."


class PoliceStationResponse(BaseModel):
    id: str
    city: str
    zone: str
    sub_division: str
    station_name: str
    contact_number: str
    address: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    distance_meters: float | None = None
    distance_display: str | None = None
    source_info: str


class NearbyPlaceItem(BaseModel):
    id: str
    name: str
    address: str | None = None
    latitude: float
    longitude: float
    distance_meters: float
    distance_display: str
    rating: float | None = None
    open_now: bool | None = None
    source: str | None = None


class NearbyHelpSummary(BaseModel):
    police: str
    hospital: str
    station: str
    active_area: str


class NearbyHelpResponse(BaseModel):
    nearest_summary: NearbyHelpSummary
    police_stations: list[dict]
    hospitals: list[dict]
    stations: list[dict]
    active_places: list[dict]
    disclaimer: str


class GuardianRouteResponse(BaseModel):
    origin: dict
    destination: dict
    evaluation_period: str
    is_night: bool
    recommended_route: dict
    alternative_routes: list[dict]
    safety_score: int
    risk_level: str
    risk_zones: list[dict]
    nearby_police: list[dict]
    nearby_hospitals: list[dict]
    nearby_stations: list[dict]
    active_places: list[dict]
    travel_time: dict
    distance: dict
    reason: str
    disclaimer: str

