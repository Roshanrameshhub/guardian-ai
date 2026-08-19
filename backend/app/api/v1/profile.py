from __future__ import annotations

from fastapi import APIRouter

from app.core.dependencies import CurrentUserId, DbSession
from app.schemas.common import ApiMessageResponse
from app.schemas.contact import (
    TrustedContactCreate,
    TrustedContactResponse,
    TrustedContactUpdate,
)
from app.schemas.user import UserResponse, UserUpdateRequest
from app.services.profile_service import ContactService, ProfileService

profile_router = APIRouter(prefix="/profile", tags=["Profile"])
contacts_router = APIRouter(prefix="/contacts", tags=["Contacts"])


# ─── Profile ──────────────────────────────────────────────────────────────────

@profile_router.get("", response_model=UserResponse)
async def get_profile(user_id: CurrentUserId, db: DbSession) -> UserResponse:
    """Get the current user's profile."""
    return await ProfileService(db).get_profile(user_id)


@profile_router.patch("", response_model=UserResponse)
async def update_profile(
    req: UserUpdateRequest, user_id: CurrentUserId, db: DbSession
) -> UserResponse:
    """Update profile fields."""
    return await ProfileService(db).update_profile(user_id, req)


# ─── Contacts ─────────────────────────────────────────────────────────────────

@contacts_router.get("", response_model=list[TrustedContactResponse])
async def list_contacts(
    user_id: CurrentUserId, db: DbSession
) -> list[TrustedContactResponse]:
    """List all trusted contacts for the current user."""
    svc = ContactService(db)
    contacts = await svc.list_contacts(user_id)
    return [
        TrustedContactResponse(
            id=c.id,
            name=c.name,
            avatar_url=c.avatar_url or "",
            is_online=c.is_online,
            phone=c.phone,
            relationship_label=c.relationship_label,
            emergency_notify_enabled=c.emergency_notify_enabled,
            location_share_enabled=c.location_share_enabled,
        )
        for c in contacts
    ]


@contacts_router.post("", response_model=TrustedContactResponse, status_code=201)
async def create_contact(
    req: TrustedContactCreate, user_id: CurrentUserId, db: DbSession
) -> TrustedContactResponse:
    """Add a trusted contact."""
    contact = await ContactService(db).create_contact(user_id, req)
    return TrustedContactResponse(
        id=contact.id,
        name=contact.name,
        avatar_url=contact.avatar_url or "",
        is_online=contact.is_online,
        phone=contact.phone,
        relationship_label=contact.relationship_label,
        emergency_notify_enabled=contact.emergency_notify_enabled,
        location_share_enabled=contact.location_share_enabled,
    )


@contacts_router.get("/{contact_id}", response_model=TrustedContactResponse)
async def get_contact(
    contact_id: str, user_id: CurrentUserId, db: DbSession
) -> TrustedContactResponse:
    """Get a single trusted contact."""
    contact = await ContactService(db).get_contact(user_id, contact_id)
    return TrustedContactResponse(
        id=contact.id,
        name=contact.name,
        avatar_url=contact.avatar_url or "",
        is_online=contact.is_online,
        phone=contact.phone,
        relationship_label=contact.relationship_label,
        emergency_notify_enabled=contact.emergency_notify_enabled,
        location_share_enabled=contact.location_share_enabled,
    )


@contacts_router.patch("/{contact_id}", response_model=TrustedContactResponse)
async def update_contact(
    contact_id: str,
    req: TrustedContactUpdate,
    user_id: CurrentUserId,
    db: DbSession,
) -> TrustedContactResponse:
    """Update a trusted contact."""
    contact = await ContactService(db).update_contact(user_id, contact_id, req)
    return TrustedContactResponse(
        id=contact.id,
        name=contact.name,
        avatar_url=contact.avatar_url or "",
        is_online=contact.is_online,
        phone=contact.phone,
        relationship_label=contact.relationship_label,
        emergency_notify_enabled=contact.emergency_notify_enabled,
        location_share_enabled=contact.location_share_enabled,
    )


@contacts_router.delete("/{contact_id}", response_model=ApiMessageResponse)
async def delete_contact(
    contact_id: str, user_id: CurrentUserId, db: DbSession
) -> ApiMessageResponse:
    """Remove a trusted contact."""
    await ContactService(db).delete_contact(user_id, contact_id)
    return ApiMessageResponse(success=True, message="Contact removed.")
