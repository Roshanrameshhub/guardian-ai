from __future__ import annotations

from typing import Generic, TypeVar

from pydantic import BaseModel

T = TypeVar("T")


class ApiMessageResponse(BaseModel):
    """Matches Flutter ApiMessageResponse."""
    success: bool
    message: str


class PaginatedResponse(BaseModel, Generic[T]):
    items: list[T]
    total: int
    page: int
    per_page: int
    has_next: bool


class WeatherResponse(BaseModel):
    temperature_c: int
    location: str
    condition: str
    visibility_km: float
    icon: str | None = None
    humidity: int | None = None


class AreaSafetyResponse(BaseModel):
    """Matches Flutter AreaSafetyEntity."""
    area_name: str
    score: int
    label: str


class SafetyEventResponse(BaseModel):
    """Matches Flutter SafetyEventEntity."""
    id: str
    time: str
    title: str
    subtitle: str


class MapPoiResponse(BaseModel):
    id: str
    name: str
    type: str
    lat: float
    lng: float


class LatLngResponse(BaseModel):
    lat: float
    lng: float


class MapRouteResponse(BaseModel):
    """Matches Flutter MapRouteEntity."""
    from_: str
    to: str
    safety_score: int
    safety_label: str
    eta_minutes: int
    traffic_label: str
    distance_km: float
    via: str
    police_nearby: int
    hospitals_nearby: int
    metro_km: float
    route_points: list[LatLngResponse]
    pois: list[MapPoiResponse]
    origin_lat: float
    origin_lng: float
    dest_lat: float
    dest_lng: float

    model_config = {"populate_by_name": True}
