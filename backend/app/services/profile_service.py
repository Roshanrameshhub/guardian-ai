from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ForbiddenError, NotFoundError
from app.models.contact import TrustedContact
from app.models.user import User, UserProfile
from app.schemas.contact import TrustedContactCreate, TrustedContactUpdate
from app.schemas.user import UserResponse, UserUpdateRequest


def _build_user_response(user: User, profile: UserProfile | None, contact_count: int) -> UserResponse:
    return UserResponse(
        id=user.id,
        name=user.full_name,
        email=user.email,
        phone=user.phone or "",
        avatar_url=(profile.avatar_url or "") if profile else "",
        is_premium=user.is_premium,
        membership_name=(profile.membership_name if profile else "Guardian Free"),
        next_billing=(profile.next_billing or "") if profile else "",
        safe_trips=(profile.safe_trips if profile else 0),
        trusted_contact_count=contact_count,
        app_version=(profile.app_version if profile else "1.2.0"),
        safety_shield_active=(profile.safety_shield_active if profile else False),
    )


class ProfileService:
    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def get_profile(self, user_id: str) -> UserResponse:
        user = await self._db.get(User, user_id)
        if not user:
            raise NotFoundError("User not found.")

        profile = await self._db.scalar(
            select(UserProfile).where(UserProfile.user_id == user_id)
        )
        contact_count = await self._db.scalar(
            select(func.count()).where(TrustedContact.user_id == user_id)
        )
        return _build_user_response(user, profile, contact_count or 0)

    async def update_profile(self, user_id: str, req: UserUpdateRequest) -> UserResponse:
        user = await self._db.get(User, user_id)
        if not user:
            raise NotFoundError("User not found.")

        if req.name is not None:
            user.full_name = req.name
        if req.phone is not None:
            user.phone = req.phone

        profile = await self._db.scalar(
            select(UserProfile).where(UserProfile.user_id == user_id)
        )
        if profile is None:
            profile = UserProfile(user_id=user_id)
            self._db.add(profile)

        if req.avatar_url is not None:
            profile.avatar_url = req.avatar_url
        if req.safety_shield_active is not None:
            profile.safety_shield_active = req.safety_shield_active

        await self._db.commit()
        await self._db.refresh(user)

        contact_count = await self._db.scalar(
            select(func.count()).where(TrustedContact.user_id == user_id)
        )
        return _build_user_response(user, profile, contact_count or 0)


class ContactService:
    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def list_contacts(self, user_id: str) -> list[TrustedContact]:
        result = await self._db.scalars(
            select(TrustedContact)
            .where(TrustedContact.user_id == user_id)
            .order_by(TrustedContact.priority)
        )
        return list(result.all())

    async def get_contact(self, user_id: str, contact_id: str) -> TrustedContact:
        contact = await self._db.get(TrustedContact, contact_id)
        if not contact:
            raise NotFoundError("Contact not found.")
        if contact.user_id != user_id:
            raise ForbiddenError()
        return contact

    async def create_contact(self, user_id: str, req: TrustedContactCreate) -> TrustedContact:
        contact = TrustedContact(
            user_id=user_id,
            name=req.name,
            phone=req.phone,
            relationship_label=req.relationship_label,
            avatar_url=req.avatar_url,
            priority=req.priority,
            emergency_notify_enabled=req.emergency_notify_enabled,
            location_share_enabled=req.location_share_enabled,
        )
        self._db.add(contact)
        await self._db.commit()
        await self._db.refresh(contact)
        return contact

    async def update_contact(
        self, user_id: str, contact_id: str, req: TrustedContactUpdate
    ) -> TrustedContact:
        contact = await self.get_contact(user_id, contact_id)
        update_data = req.model_dump(exclude_none=True)
        for field, value in update_data.items():
            setattr(contact, field, value)
        await self._db.commit()
        await self._db.refresh(contact)
        return contact

    async def delete_contact(self, user_id: str, contact_id: str) -> None:
        contact = await self.get_contact(user_id, contact_id)
        await self._db.delete(contact)
        await self._db.commit()
