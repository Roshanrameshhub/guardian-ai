from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import List
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.intelligence import CheckInStatus, SafetyCheckIn
from app.schemas.intelligence import (
    CheckInConfirmResponse,
    CheckInResponse,
    CheckInStartRequest,
)


def _checkin_to_response(c: SafetyCheckIn) -> CheckInResponse:
    now = datetime.now(tz=timezone.utc)
    expires_at = c.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    remaining_secs = max(0, int((expires_at - now).total_seconds()))
    return CheckInResponse(
        id=c.id,
        title=c.title,
        duration_minutes=c.duration_minutes,
        status=c.status.value.upper(),
        started_at=c.started_at.isoformat(),
        expires_at=c.expires_at.isoformat(),
        confirmed_at=c.confirmed_at.isoformat() if c.confirmed_at else None,
        minutes_remaining=int(remaining_secs / 60),
    )


class CheckInService:
    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def start_checkin(
        self, user_id: str, req: CheckInStartRequest
    ) -> CheckInResponse:
        now = datetime.now(tz=timezone.utc)
        expires_at = now + timedelta(minutes=req.duration_minutes)

        checkin = SafetyCheckIn(
            user_id=user_id,
            title=req.title,
            duration_minutes=req.duration_minutes,
            status=CheckInStatus.active,
            started_at=now,
            expires_at=expires_at,
            prompt_message=req.prompt_message,
        )
        self._db.add(checkin)
        await self._db.commit()
        await self._db.refresh(checkin)

        return _checkin_to_response(checkin)

    async def confirm_checkin(
        self, user_id: str, checkin_id: str
    ) -> CheckInConfirmResponse:
        checkin = await self._db.get(SafetyCheckIn, checkin_id)
        if not checkin or checkin.user_id != user_id:
            return CheckInConfirmResponse(
                success=False, status="NOT_FOUND", message="Check-in session not found."
            )

        if checkin.status != CheckInStatus.active:
            return CheckInConfirmResponse(
                success=True,
                status=checkin.status.value.upper(),
                message=f"Check-in already {checkin.status.value}.",
            )

        checkin.status = CheckInStatus.confirmed
        checkin.confirmed_at = datetime.now(tz=timezone.utc)
        await self._db.commit()

        return CheckInConfirmResponse(
            success=True,
            status="CONFIRMED",
            message="Safety check-in successfully confirmed.",
        )

    async def cancel_checkin(
        self, user_id: str, checkin_id: str
    ) -> CheckInConfirmResponse:
        checkin = await self._db.get(SafetyCheckIn, checkin_id)
        if not checkin or checkin.user_id != user_id:
            return CheckInConfirmResponse(
                success=False, status="NOT_FOUND", message="Check-in session not found."
            )

        checkin.status = CheckInStatus.cancelled
        await self._db.commit()

        return CheckInConfirmResponse(
            success=True,
            status="CANCELLED",
            message="Safety check-in cancelled by user.",
        )

    async def list_checkins(self, user_id: str) -> List[CheckInResponse]:
        result = await self._db.scalars(
            select(SafetyCheckIn)
            .where(SafetyCheckIn.user_id == user_id)
            .order_by(SafetyCheckIn.started_at.desc())
            .limit(20)
        )
        return [_checkin_to_response(c) for c in result.all()]
