from __future__ import annotations

from typing import List
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.intelligence import RiskAssessment, RiskLevel
from app.schemas.intelligence import (
    RiskFusionRequest,
    RiskFusionResponse,
    RiskSignalDetail,
)


class RiskFusionService:
    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    # Weights for individual signal categories
    SIGNAL_WEIGHTS = {
        "VOICE_DISTRESS": 0.35,
        "MOTION_ANOMALY": 0.20,
        "PHONE_DROP": 0.25,
        "SHAKE": 0.20,
        "SUDDEN_STOP": 0.15,
        "ROUTE_DEVIATION": 0.25,
        "CHECKIN_MISSED": 0.30,
    }

    async def fuse_signals(
        self, user_id: str, req: RiskFusionRequest
    ) -> RiskFusionResponse:
        signal_details: List[RiskSignalDetail] = []
        weighted_sum = 0.0
        total_weight_used = 0.0

        for sig in req.signals:
            sig_type = sig.type.upper()
            weight = self.SIGNAL_WEIGHTS.get(sig_type, 0.15)
            effective_score = sig.score * sig.confidence
            contribution = effective_score * weight

            weighted_sum += contribution
            total_weight_used += weight

            # Build human-readable explanation for each signal
            if "VOICE" in sig_type:
                exp = f"Voice distress detected with urgency score {sig.score:.2f}."
            elif "DROP" in sig_type:
                exp = "Phone impact and sudden drop signature detected."
            elif "SHAKE" in sig_type:
                exp = "Violent shake motion pattern detected."
            elif "DEVIATION" in sig_type:
                exp = "Path deviated significantly from planned route corridor."
            elif "MOTION" in sig_type:
                exp = "Abnormal acceleration and rotation variance detected."
            else:
                exp = f"Signal {sig_type} active with score {sig.score:.2f}."

            signal_details.append(
                RiskSignalDetail(
                    type=sig_type,
                    score=round(sig.score, 2),
                    weighted_contribution=round(contribution, 3),
                    explanation=exp,
                )
            )

        # Multi-signal synergistic boost (e.g. Voice Distress + Motion Anomaly at the same time)
        active_critical_signals = sum(
            1 for s in req.signals if s.score >= 0.60
        )
        if active_critical_signals >= 2:
            weighted_sum = min(1.0, weighted_sum * 1.30)

        # Context modifiers
        if req.guardian_mode_active:
            # Under active guardian monitoring, sensitivity is slightly elevated
            weighted_sum = min(1.0, weighted_sum * 1.10)
        
        if req.nearby_safety_incident:
            # Active local safety incident in immediate vicinity
            weighted_sum = min(1.0, weighted_sum + 0.10)

        final_risk_score = round(min(1.0, max(0.0, weighted_sum)), 2)

        # Risk Tier Classification
        if final_risk_score >= 0.80:
            risk_level = RiskLevel.critical
            recommended_action = "CRITICAL: Immediate emergency confirmation countdown initiated."
            requires_prompt = True
            auto_escalate = True
        elif final_risk_score >= 0.60:
            risk_level = RiskLevel.high
            recommended_action = "HIGH: Displaying emergency prompt; preparing trusted contact notification."
            requires_prompt = True
            auto_escalate = False
        elif final_risk_score >= 0.35:
            risk_level = RiskLevel.medium
            recommended_action = "MEDIUM: Displaying 'Are you okay?' safety check."
            requires_prompt = True
            auto_escalate = False
        else:
            risk_level = RiskLevel.low
            recommended_action = "LOW: Passive monitoring; conditions appear normal."
            requires_prompt = False
            auto_escalate = False

        # Persist Assessment
        assessment = RiskAssessment(
            user_id=user_id,
            journey_id=req.journey_id,
            risk_level=risk_level,
            risk_score=final_risk_score,
            signals_breakdown=[s.model_dump() for s in signal_details],
            recommended_action=recommended_action,
        )
        self._db.add(assessment)
        await self._db.commit()

        return RiskFusionResponse(
            risk_level=risk_level.value.upper(),
            risk_score=final_risk_score,
            signals=signal_details,
            recommended_action=recommended_action,
            requires_user_prompt=requires_prompt,
            auto_escalate_prepared=auto_escalate,
        )
