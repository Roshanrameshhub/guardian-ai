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


class GuardianSessionStatus(str, enum.Enum):
    active = "active"
    paused = "paused"
    stopped = "stopped"
    stale = "stale"
    emergency = "emergency"


class GuardianSession(Base):
    __tablename__ = "guardian_sessions"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(
        UUID(as_uuid=False), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    journey_id: Mapped[str | None] = mapped_column(
        UUID(as_uuid=False), ForeignKey("journeys.id", ondelete="SET NULL"), nullable=True
    )
    status: Mapped[GuardianSessionStatus] = mapped_column(
        SAEnum(GuardianSessionStatus), default=GuardianSessionStatus.active, nullable=False, index=True
    )
    origin: Mapped[str | None] = mapped_column(String(500), nullable=True)
    destination: Mapped[str | None] = mapped_column(String(500), nullable=True)
    # Live metrics (updated frequently)
    current_lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    current_lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    current_location_name: Mapped[str | None] = mapped_column(String(500), nullable=True)
    battery_percent: Mapped[int | None] = mapped_column(Integer, nullable=True)
    speed_kmh: Mapped[float | None] = mapped_column(Float, nullable=True)
    progress: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    estimated_arrival: Mapped[str | None] = mapped_column(String(20), nullable=True)
    minutes_left: Mapped[int | None] = mapped_column(Integer, nullable=True)
    # Timing
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, nullable=False)
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    last_heartbeat: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    # Trigger source
    trigger_source: Mapped[str] = mapped_column(String(50), default="manual", nullable=False)

    user: Mapped["User"] = relationship("User", back_populates="guardian_sessions")
