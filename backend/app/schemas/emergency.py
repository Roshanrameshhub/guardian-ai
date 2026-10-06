from __future__ import annotations

from pydantic import BaseModel


class SosRequest(BaseModel):
    """Matches Flutter SosRequest."""
    lat: float
    lng: float
    message: str | None = None
    trigger_source: str = "manual"  # manual / voice / button / guardian_timeout / system_event


class NotificationDeliveryItem(BaseModel):
    contact_name: str
    channel: str
    delivery_status: str  # sent, failed, unconfigured
    detail: str | None = None


class EmergencyResponse(BaseModel):
    """Matches Flutter ApiMessageResponse + adds emergency event state."""
    success: bool
    message: str
    event_id: str | None = None
    status: str | None = None
    delivery_details: list[NotificationDeliveryItem] = []


class EmergencyCancelRequest(BaseModel):
    reason: str | None = None
