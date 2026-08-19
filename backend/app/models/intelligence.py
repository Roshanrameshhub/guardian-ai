from __future__ import annotations

import enum
import uuid
from datetime import datetime, timezone
from typing import Any

from sqlalchemy import (
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    JSON,
    String,
    Text,
    Enum as SAEnum,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


def _uuid() -> str:
    return str(uuid.uuid4())


def _now() -> datetime:
    return datetime.now(tz=timezone.utc)


# ─── Risk & Signals Enums ─────────────────────────────────────────────────────

class RiskLevel(str, enum.Enum):
    low = "low"
    medium = "medium"
    high = "high"
    critical = "critical"


class SignalType(str, enum.Enum):
    voice_distress = "voice_distress"
    motion_anomaly = "motion_anomaly"
    shake_detected = "shake_detected"
    phone_drop = "phone_drop"
    route_deviation = "route_deviation"
    safe_arrival = "safe_arrival"
    checkin_expired = "checkin_expired"
    checkin_confirmed = "checkin_confirmed"
    risk_level_changed = "risk_level_changed"
    false_positive = "false_positive"


class CheckInStatus(str, enum.Enum):
    active = "active"
    confirmed = "confirmed"
    expired = "expired"
    cancelled = "cancelled"


class DeviationSeverity(str, enum.Enum):
    normal = "normal"
    minor = "minor"
    significant = "significant"
    confirmed = "confirmed"
    emergency = "emergency"


# ─── Models ───────────────────────────────────────────────────────────────────

class MotionAnomalyEvent(Base):
    __tablename__ = "motion_anomaly_events"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(
        UUID(as_uuid=False), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    journey_id: Mapped[str | None] = mapped_column(
        UUID(as_uuid=False), ForeignKey("journeys.id", ondelete="SET NULL"), nullable=True
    )
    event_type: Mapped[str] = mapped_column(String(50), default="MOTION_ANOMALY", nullable=False)
    duration_ms: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    acceleration_peak: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    rotation_peak: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    sudden_stop: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    confidence: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    raw_metrics: Mapped[dict[str, Any] | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, nullable=False)


class PersonalMotionProfile(Base):
    __tablename__ = "personal_motion_profiles"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(
        UUID(as_uuid=False), ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False
    )
    avg_walking_accel: Mapped[float] = mapped_column(Float, default=1.2, nullable=False)
    avg_running_accel: Mapped[float] = mapped_column(Float, default=2.5, nullable=False)
    shake_sensitivity_mod: Mapped[float] = mapped_column(Float, default=1.0, nullable=False)
    false_alarm_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_now, onupdate=_now, nullable=False
    )


class VoiceDistressEvent(Base):
    __tablename__ = "voice_distress_events"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(
        UUID(as_uuid=False), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    journey_id: Mapped[str | None] = mapped_column(
        UUID(as_uuid=False), ForeignKey("journeys.id", ondelete="SET NULL"), nullable=True
    )
    distress_score: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    urgency: Mapped[str] = mapped_column(String(20), default="LOW", nullable=False)
    help_keyword_detected: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    repetition_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    voice_intensity: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    model_confidence: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    matched_keywords: Mapped[list[str] | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, nullable=False)


class RiskAssessment(Base):
    __tablename__ = "risk_assessments"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(
        UUID(as_uuid=False), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    journey_id: Mapped[str | None] = mapped_column(
        UUID(as_uuid=False), ForeignKey("journeys.id", ondelete="SET NULL"), nullable=True
    )
    risk_level: Mapped[RiskLevel] = mapped_column(SAEnum(RiskLevel), default=RiskLevel.low, nullable=False)
    risk_score: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    signals_breakdown: Mapped[list[dict[str, Any]]] = mapped_column(JSON, default=list, nullable=False)
    recommended_action: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, nullable=False)


class FalsePositiveRecord(Base):
    __tablename__ = "false_positive_records"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(
        UUID(as_uuid=False), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    event_id: Mapped[str | None] = mapped_column(String(100), nullable=True)
    trigger_source: Mapped[str] = mapped_column(String(100), nullable=False)
    user_response: Mapped[str] = mapped_column(String(50), default="I_AM_SAFE", nullable=False)
    final_outcome: Mapped[str] = mapped_column(String(50), default="false_alarm", nullable=False)
    voice_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    motion_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    route_deviation: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, nullable=False)


class SafetyCheckIn(Base):
    __tablename__ = "safety_check_ins"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(
        UUID(as_uuid=False), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    title: Mapped[str] = mapped_column(String(255), default="Safety Check-In", nullable=False)
    duration_minutes: Mapped[int] = mapped_column(Integer, default=15, nullable=False)
    status: Mapped[CheckInStatus] = mapped_column(
        SAEnum(CheckInStatus), default=CheckInStatus.active, nullable=False
    )
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    confirmed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    escalated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    prompt_message: Mapped[str | None] = mapped_column(String(500), nullable=True)


class LocationShareSession(Base):
    __tablename__ = "location_share_sessions"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(
        UUID(as_uuid=False), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    share_token: Mapped[str] = mapped_column(String(100), unique=True, nullable=False, index=True)
    journey_id: Mapped[str | None] = mapped_column(
        UUID(as_uuid=False), ForeignKey("journeys.id", ondelete="SET NULL"), nullable=True
    )
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, nullable=False)


class SyncRecord(Base):
    __tablename__ = "sync_records"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(
        UUID(as_uuid=False), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    idempotency_key: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    entity_type: Mapped[str] = mapped_column(String(100), nullable=False)
    payload: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False)
    synced_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, nullable=False)
