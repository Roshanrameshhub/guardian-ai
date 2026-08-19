from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import (
    Boolean, DateTime, Float, ForeignKey, Integer, String, Text, Enum as SAEnum
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
import enum

from app.core.database import Base


def _uuid() -> str:
    return str(uuid.uuid4())


def _now() -> datetime:
    return datetime.now(tz=timezone.utc)


class JourneyStatus(str, enum.Enum):
    planned = "planned"
    active = "active"
    completed = "completed"
    cancelled = "cancelled"
    expired = "expired"


class Journey(Base):
    __tablename__ = "journeys"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(
        UUID(as_uuid=False), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    title: Mapped[str] = mapped_column(String(500), nullable=False)
    origin: Mapped[str] = mapped_column(String(500), nullable=False)
    destination: Mapped[str] = mapped_column(String(500), nullable=False)
    origin_lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    origin_lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    dest_lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    dest_lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    status: Mapped[JourneyStatus] = mapped_column(
        SAEnum(JourneyStatus), default=JourneyStatus.planned, nullable=False, index=True
    )
    safety_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    is_alert: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    completed_safely: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    distance_km: Mapped[float | None] = mapped_column(Float, nullable=True)
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_now, onupdate=_now, nullable=False
    )

    # Guardian session linked to this journey
    guardian_session_id: Mapped[str | None] = mapped_column(
        UUID(as_uuid=False), ForeignKey("guardian_sessions.id", ondelete="SET NULL"), nullable=True
    )

    user: Mapped["User"] = relationship("User", back_populates="journeys")
    locations: Mapped[list[JourneyLocation]] = relationship(
        "JourneyLocation", back_populates="journey", cascade="all, delete-orphan"
    )
    events: Mapped[list[JourneyEvent]] = relationship(
        "JourneyEvent", back_populates="journey", cascade="all, delete-orphan"
    )


class JourneyLocation(Base):
    __tablename__ = "journey_locations"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    journey_id: Mapped[str] = mapped_column(
        UUID(as_uuid=False), ForeignKey("journeys.id", ondelete="CASCADE"), nullable=False, index=True
    )
    lat: Mapped[float] = mapped_column(Float, nullable=False)
    lng: Mapped[float] = mapped_column(Float, nullable=False)
    accuracy_m: Mapped[float | None] = mapped_column(Float, nullable=True)
    speed_kmh: Mapped[float | None] = mapped_column(Float, nullable=True)
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, nullable=False)

    journey: Mapped[Journey] = relationship("Journey", back_populates="locations")


class JourneyEventType(str, enum.Enum):
    started = "started"
    location_update = "location_update"
    deviation = "deviation"
    checkin = "checkin"
    checkin_missed = "checkin_missed"
    safe_arrival = "safe_arrival"
    completed = "completed"
    cancelled = "cancelled"
    sos_triggered = "sos_triggered"


class JourneyEvent(Base):
    __tablename__ = "journey_events"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    journey_id: Mapped[str] = mapped_column(
        UUID(as_uuid=False), ForeignKey("journeys.id", ondelete="CASCADE"), nullable=False, index=True
    )
    event_type: Mapped[JourneyEventType] = mapped_column(SAEnum(JourneyEventType), nullable=False)
    title: Mapped[str] = mapped_column(String(500), nullable=False)
    subtitle: Mapped[str | None] = mapped_column(String(500), nullable=True)
    lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, nullable=False)

    journey: Mapped[Journey] = relationship("Journey", back_populates="events")
