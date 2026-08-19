from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


def _uuid() -> str:
    return str(uuid.uuid4())


def _now() -> datetime:
    return datetime.now(tz=timezone.utc)


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(
        UUID(as_uuid=False), primary_key=True, default=_uuid
    )
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
    phone: Mapped[str | None] = mapped_column(String(50), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    is_premium: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_now, nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_now, onupdate=_now, nullable=False
    )

    # Relationships
    profile: Mapped[UserProfile | None] = relationship(
        "UserProfile", back_populates="user", uselist=False, cascade="all, delete-orphan"
    )
    refresh_tokens: Mapped[list[RefreshToken]] = relationship(
        "RefreshToken", back_populates="user", cascade="all, delete-orphan"
    )
    preferences: Mapped[UserPreference | None] = relationship(
        "UserPreference", back_populates="user", uselist=False, cascade="all, delete-orphan"
    )
    contacts: Mapped[list["TrustedContact"]] = relationship(
        "TrustedContact", back_populates="user", cascade="all, delete-orphan"
    )
    journeys: Mapped[list["Journey"]] = relationship(
        "Journey", back_populates="user", cascade="all, delete-orphan"
    )
    guardian_sessions: Mapped[list["GuardianSession"]] = relationship(
        "GuardianSession", back_populates="user", cascade="all, delete-orphan"
    )
    notifications: Mapped[list["Notification"]] = relationship(
        "Notification", back_populates="user", cascade="all, delete-orphan"
    )
    device_tokens: Mapped[list["DeviceToken"]] = relationship(
        "DeviceToken", back_populates="user", cascade="all, delete-orphan"
    )
    emergency_events: Mapped[list["EmergencyEvent"]] = relationship(
        "EmergencyEvent", back_populates="user", cascade="all, delete-orphan"
    )
    user_achievements: Mapped[list["UserAchievement"]] = relationship(
        "UserAchievement", back_populates="user", cascade="all, delete-orphan"
    )
    ai_conversations: Mapped[list["AiConversation"]] = relationship(
        "AiConversation", back_populates="user", cascade="all, delete-orphan"
    )


class UserProfile(Base):
    __tablename__ = "user_profiles"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(
        UUID(as_uuid=False), ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False
    )
    avatar_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    membership_name: Mapped[str] = mapped_column(String(100), default="Guardian Free", nullable=False)
    next_billing: Mapped[str | None] = mapped_column(String(50), nullable=True)
    safe_trips: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    safety_shield_active: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    app_version: Mapped[str] = mapped_column(String(20), default="1.2.0", nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_now, onupdate=_now, nullable=False
    )

    user: Mapped[User] = relationship("User", back_populates="profile")


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(
        UUID(as_uuid=False), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    token_hash: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, nullable=False)
    device_info: Mapped[str | None] = mapped_column(String(255), nullable=True)

    user: Mapped[User] = relationship("User", back_populates="refresh_tokens")


class UserPreference(Base):
    __tablename__ = "user_preferences"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(
        UUID(as_uuid=False), ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False
    )
    # Privacy
    location_sharing_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    guardian_mode_auto_start: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    # Notifications
    push_notifications_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    emergency_sms_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    safe_arrival_notify_contacts: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    # AI
    ai_data_usage_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    ai_insights_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    # Journey
    journey_history_retention_days: Mapped[int] = mapped_column(Integer, default=90, nullable=False)
    # Guardian
    guardian_heartbeat_interval_seconds: Mapped[int] = mapped_column(Integer, default=30, nullable=False)
    guardian_checkin_interval_minutes: Mapped[int] = mapped_column(Integer, default=15, nullable=False)
    guardian_escalation_level: Mapped[int] = mapped_column(Integer, default=2, nullable=False)

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_now, onupdate=_now, nullable=False
    )

    user: Mapped[User] = relationship("User", back_populates="preferences")
