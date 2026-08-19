from __future__ import annotations

from pydantic import BaseModel


class WeatherResponse(BaseModel):
    temperature_c: int
    location: str
    condition: str
    visibility_km: float
    icon: str | None = None
    humidity: int | None = None


class AreaSafetyResponse(BaseModel):
    area_name: str
    score: int
    label: str


class SafetyEventResponse(BaseModel):
    id: str
    time: str
    title: str
    subtitle: str
