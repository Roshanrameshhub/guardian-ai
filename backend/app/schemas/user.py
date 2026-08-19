from __future__ import annotations

from pydantic import BaseModel, HttpUrl


class UserResponse(BaseModel):
    """Matches Flutter UserEntity exactly."""
    id: str
    name: str
    email: str
    phone: str
    avatar_url: str
    is_premium: bool
    membership_name: str
    next_billing: str
    safe_trips: int
    trusted_contact_count: int
    app_version: str
    safety_shield_active: bool

    model_config = {"from_attributes": True}


class UserUpdateRequest(BaseModel):
    name: str | None = None
    phone: str | None = None
    avatar_url: str | None = None
    safety_shield_active: bool | None = None
