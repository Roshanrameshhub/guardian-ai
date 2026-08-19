from __future__ import annotations

import uuid
import enum
from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, String, Text, Enum as SAEnum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


def _uuid() -> str:
    return str(uuid.uuid4())


def _now() -> datetime:
    return datetime.now(tz=timezone.utc)


class EmergencyStatus(str, enum.Enum):
    created = "created"
    processing = "processing"
    notifications_queued = "notifications_queued"
    active = "active"
    cancelled = "cancelled"
    resolved = "resolved"


class NotificationDeliveryStatus(str, enum.Enum):
    queued = "queued"
    sent = "sent"
    delivered = "delivered"
    failed = "failed"


class EmergencyEvent(Base):
    __tablename__ = "emergency_events"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(
        UUID(as_uuid=False), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    status: Mapped[EmergencyStatus] = mapped_column(
        SAEnum(EmergencyStatus), default=EmergencyStatus.created, nullable=False, index=True
    )
    trigger_source: Mapped[str] = mapped_column(String(50), default="manual", nullable=False)
    # Location at time of SOS
    lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    location_name: Mapped[str | None] = mapped_column(String(500), nullable=True)
    message: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Guardian session if active
    guardian_session_id: Mapped[str | None] = mapped_column(
        UUID(as_uuid=False), ForeignKey("guardian_sessions.id", ondelete="SET NULL"), nullable=True
    )
    # Timing
    triggered_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, nullable=False)
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    user: Mapped["User"] = relationship("User", back_populates="emergency_events")
    notifications: Mapped[list[EmergencyNotification]] = relationship(
        "EmergencyNotification", back_populates="event", cascade="all, delete-orphan"
    )


class EmergencyNotification(Base):
    __tablename__ = "emergency_notifications"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    event_id: Mapped[str] = mapped_column(
        UUID(as_uuid=False), ForeignKey("emergency_events.id", ondelete="CASCADE"), nullable=False, index=True
    )
    contact_id: Mapped[str | None] = mapped_column(
        UUID(as_uuid=False), ForeignKey("trusted_contacts.id", ondelete="SET NULL"), nullable=True
    )
    channel: Mapped[str] = mapped_column(String(20), nullable=False)  # push / sms / email
    recipient: Mapped[str] = mapped_column(String(255), nullable=False)  # phone or email
    delivery_status: Mapped[NotificationDeliveryStatus] = mapped_column(
        SAEnum(NotificationDeliveryStatus), default=NotificationDeliveryStatus.queued, nullable=False
    )
    sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    delivered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    failure_reason: Mapped[str | None] = mapped_column(String(500), nullable=True)

    event: Mapped[EmergencyEvent] = relationship("EmergencyEvent", back_populates="notifications")
