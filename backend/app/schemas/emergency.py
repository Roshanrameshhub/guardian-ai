from __future__ import annotations

from pydantic import BaseModel


class SosRequest(BaseModel):
    """Matches Flutter SosRequest."""
    lat: float
    lng: float
    message: str | None = None
    trigger_source: str = "manual"  # manual / voice / button / guardian_timeout / system_event


class EmergencyResponse(BaseModel):
    """Matches Flutter ApiMessageResponse + adds emergency event state."""
    success: bool
    message: str
    event_id: str | None = None
    status: str | None = None


class EmergencyCancelRequest(BaseModel):
    reason: str | None = None
