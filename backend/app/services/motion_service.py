from __future__ import annotations

import math
from typing import Any
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.intelligence import MotionAnomalyEvent, PersonalMotionProfile
from app.schemas.intelligence import MotionSignalRequest, MotionSignalResponse


class MotionSignalService:
    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def process_motion_signal(
        self, user_id: str, req: MotionSignalRequest
    ) -> MotionSignalResponse:
        # Load or create personal motion baseline
        profile = await self._db.scalar(
            select(PersonalMotionProfile).where(PersonalMotionProfile.user_id == user_id)
        )
        if not profile:
            profile = PersonalMotionProfile(user_id=user_id)
            self._db.add(profile)
            await self._db.flush()

        # Evaluate raw motion contribution
        accel = req.acceleration_peak
        rot = req.rotation_peak
        duration = req.duration_ms
        event_type = req.event_type.upper()

        risk_contribution = 0.0

        # Classification logic based on sensor signatures
        if "SHAKE" in event_type or (accel >= 2.5 and rot >= 3.0 and duration <= 2000):
            # Shake event
            event_type = "SHAKE_DETECTED"
            risk_contribution = min(1.0, 0.40 + (accel / 5.0) * 0.40)
        elif "DROP" in event_type or (accel >= 3.5 and req.sudden_stop):
            # Phone drop event (impact spike + sudden stop)
            event_type = "PHONE_DROP"
            risk_contribution = 0.65
        elif req.sudden_stop and accel >= 2.0:
            # Sudden abrupt deceleration
            event_type = "SUDDEN_STOP"
            risk_contribution = 0.50
        else:
            # Generic motion anomaly
            event_type = "MOTION_ANOMALY"
            risk_contribution = min(1.0, (accel / 4.0) * 0.50 + (rot / 5.0) * 0.30)

        # Baseline sensitivity modulation:
        # If user has a high false alarm profile or higher baseline running acceleration,
        # moderately tune confidence without fully suppressing the alert.
        adjusted_confidence = req.confidence
        if profile.false_alarm_count >= 3:
            adjusted_confidence = max(0.40, req.confidence * 0.85)
        
        # Save event
        event = MotionAnomalyEvent(
            user_id=user_id,
            journey_id=req.journey_id,
            event_type=event_type,
            duration_ms=req.duration_ms,
            acceleration_peak=req.acceleration_peak,
            rotation_peak=req.rotation_peak,
            sudden_stop=req.sudden_stop,
            confidence=adjusted_confidence,
            raw_metrics=req.raw_metrics,
        )
        self._db.add(event)
        await self._db.commit()

        message = (
            f"Motion signal '{event_type}' processed with peak accel {accel:.2f}g, "
            f"risk contribution {risk_contribution:.2f}."
        )

        return MotionSignalResponse(
            success=True,
            event_id=event.id,
            event_type=event_type,
            evaluated_risk_contribution=round(risk_contribution, 2),
            confidence_adjusted=round(adjusted_confidence, 2),
            message=message,
        )
