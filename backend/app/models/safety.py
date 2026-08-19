from __future__ import annotations

import uuid
import enum
from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Enum as SAEnum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


def _uuid() -> str:
    return str(uuid.uuid4())


def _now() -> datetime:
    return datetime.now(tz=timezone.utc)


class SafetyEventType(str, enum.Enum):
    incident_reported = "incident_reported"
    guardian_stale = "guardian_stale"
    journey_deviation = "journey_deviation"
    checkin_missed = "checkin_missed"
    safe_arrival = "safe_arrival"
    sos_triggered = "sos_triggered"
    area_alert = "area_alert"


class SafetySeverity(str, enum.Enum):
    info = "info"
    low = "low"
    medium = "medium"
    high = "high"
    critical = "critical"


class SafetyEvent(Base):
    __tablename__ = "safety_events"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id: Mapped[str | None] = mapped_column(
        UUID(as_uuid=False), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    event_type: Mapped[SafetyEventType] = mapped_column(SAEnum(SafetyEventType), nullable=False, index=True)
    severity: Mapped[SafetySeverity] = mapped_column(
        SAEnum(SafetySeverity), default=SafetySeverity.info, nullable=False
    )
    title: Mapped[str] = mapped_column(String(500), nullable=False)
    subtitle: Mapped[str | None] = mapped_column(String(500), nullable=True)
    lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    area_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, nullable=False, index=True)
    reference_id: Mapped[str | None] = mapped_column(String(100), nullable=True)


class SafetyAreaScore(Base):
    __tablename__ = "safety_area_scores"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    area_name: Mapped[str] = mapped_column(String(255), nullable=False, unique=True, index=True)
    score: Mapped[int] = mapped_column(Integer, nullable=False)
    label: Mapped[str] = mapped_column(String(50), nullable=False)
    center_lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    center_lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    radius_km: Mapped[float] = mapped_column(Float, default=2.0, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_now, onupdate=_now, nullable=False
    )


class PoliceStation(Base):
    """
    Official Chennai Police Station directory data.
    Preserves exact station name, zone, subdivision, phone numbers, and coordinates.
    Treated as informational directory data.
    """
    __tablename__ = "police_stations"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    city: Mapped[str] = mapped_column(String(100), default="Chennai", nullable=False, index=True)
    zone: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    sub_division: Mapped[str] = mapped_column(String(150), nullable=False, index=True)
    station_name: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    contact_number: Mapped[str] = mapped_column(String(100), nullable=False)
    address: Mapped[str | None] = mapped_column(String(500), nullable=True)
    latitude: Mapped[float | None] = mapped_column(Float, nullable=True, index=True)
    longitude: Mapped[float | None] = mapped_column(Float, nullable=True, index=True)
    source_info: Mapped[str] = mapped_column(
        String(500),
        default="Chennai Police Department directory - informational prototype data",
        nullable=False,
    )
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, nullable=False)


class SafetyZone(Base):
    """
    Demo/Prototype Safety Zone dataset for Chennai.
    NOTE: Prototype/demo data only — not official crime statistics.
    """
    __tablename__ = "safety_zones"

    id: Mapped[str] = mapped_column(String(50), primary_key=True)  # e.g. 'CHN001'
    place: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    category: Mapped[str] = mapped_column(String(100), nullable=False)
    anchor_area: Mapped[str] = mapped_column(String(150), nullable=False, index=True)
    demo_safety_label: Mapped[str] = mapped_column(String(100), nullable=False)
    day_risk_score: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    night_risk_score: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    route_risk_score: Mapped[int] = mapped_column(Integer, nullable=False)
    footfall: Mapped[str] = mapped_column(String(50), nullable=False)
    night_activity: Mapped[str] = mapped_column(String(50), nullable=False)
    lighting: Mapped[str] = mapped_column(String(50), nullable=False)
    isolation: Mapped[str] = mapped_column(String(50), nullable=False)
    recommendation: Mapped[str] = mapped_column(String(500), nullable=False)
    data_status: Mapped[str] = mapped_column(String(255), nullable=False)
    source_basis: Mapped[str] = mapped_column(String(1000), nullable=False)
    crime_data: Mapped[str] = mapped_column(String(255), nullable=False)
    use_for_routing: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    geocode_query: Mapped[str] = mapped_column(String(500), nullable=False)
    demo_safety_score: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    latitude: Mapped[float] = mapped_column(Float, nullable=False, index=True)
    longitude: Mapped[float] = mapped_column(Float, nullable=False, index=True)
    radius_meters: Mapped[float] = mapped_column(Float, default=600.0, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, nullable=False)

