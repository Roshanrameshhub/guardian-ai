from __future__ import annotations

from pydantic import BaseModel


class TrustedContactResponse(BaseModel):
    """Matches Flutter TrustedContactEntity."""
    id: str
    name: str
    avatar_url: str
    is_online: bool
    phone: str
    relationship_label: str | None = None
    emergency_notify_enabled: bool = True
    location_share_enabled: bool = False
    is_telegram_linked: bool = False

    model_config = {"from_attributes": True}

class TelegramLinkResponse(BaseModel):
    link_token: str
    bot_username: str
    expires_in_minutes: int


class TrustedContactCreate(BaseModel):
    name: str
    phone: str
    relationship_label: str | None = None
    avatar_url: str | None = None
    priority: int = 1
    emergency_notify_enabled: bool = True
    location_share_enabled: bool = False


class TrustedContactUpdate(BaseModel):
    name: str | None = None
    phone: str | None = None
    relationship_label: str | None = None
    avatar_url: str | None = None
    priority: int | None = None
    emergency_notify_enabled: bool | None = None
    location_share_enabled: bool | None = None
