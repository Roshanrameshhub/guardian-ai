from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.intelligence import FalsePositiveRecord, PersonalMotionProfile
from app.schemas.intelligence import (
    FalsePositiveFeedbackRequest,
    FalsePositiveFeedbackResponse,
)


class FalsePositiveService:
    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def record_feedback(
        self, user_id: str, req: FalsePositiveFeedbackRequest
    ) -> FalsePositiveFeedbackResponse:
        # 1. Store the feedback record
        record = FalsePositiveRecord(
            user_id=user_id,
            event_id=req.event_id,
            trigger_source=req.trigger_source,
            user_response=req.user_response,
            final_outcome="false_alarm" if "SAFE" in req.user_response.upper() else "confirmed_emergency",
            voice_score=req.voice_score,
            motion_score=req.motion_score,
            route_deviation=req.route_deviation,
            notes=req.notes,
        )
        self._db.add(record)

        # 2. Update user's personal motion baseline if it was a motion-related false alarm
        profile_adjusted = False
        profile = await self._db.scalar(
            select(PersonalMotionProfile).where(PersonalMotionProfile.user_id == user_id)
        )
        if not profile:
            profile = PersonalMotionProfile(user_id=user_id)
            self._db.add(profile)
            await self._db.flush()

        if "false_alarm" in record.final_outcome:
            profile.false_alarm_count += 1
            if "MOTION" in req.trigger_source.upper() or "SHAKE" in req.trigger_source.upper():
                # Slightly decrease sensitivity modifier to account for workout / transit noise
                profile.shake_sensitivity_mod = max(0.60, profile.shake_sensitivity_mod * 0.95)
                profile_adjusted = True

        await self._db.commit()

        message = (
            "Safety feedback logged. "
            f"Outcome: {record.final_outcome}. "
            f"Personal motion baseline sensitivity: {profile.shake_sensitivity_mod:.2f}."
        )

        return FalsePositiveFeedbackResponse(
            success=True,
            message=message,
            motion_profile_adjusted=profile_adjusted,
            current_false_alarm_count=profile.false_alarm_count,
        )
