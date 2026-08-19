from __future__ import annotations

from typing import List
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.contact import TrustedContact
from app.models.guardian import GuardianSession
from app.models.journey import Journey
from app.schemas.intelligence import SafetyRecommendationItem


class RecommendationService:
    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def get_personalized_recommendations(
        self, user_id: str
    ) -> List[SafetyRecommendationItem]:
        recommendations: List[SafetyRecommendationItem] = []

        # 1. Contact Count Check
        contact_count = await self._db.scalar(
            select(func.count()).where(TrustedContact.user_id == user_id)
        ) or 0
        if contact_count == 0:
            recommendations.append(
                SafetyRecommendationItem(
                    id="rec_add_contact",
                    title="Add a Trusted Contact",
                    category="Trusted Circle",
                    evidence="No emergency contacts configured yet.",
                    action_type="ADD_CONTACT",
                    action_label="Add Contact",
                )
            )
        elif contact_count < 2:
            recommendations.append(
                SafetyRecommendationItem(
                    id="rec_expand_circle",
                    title="Expand your Trusted Circle",
                    category="Trusted Circle",
                    evidence=f"You have {contact_count} contact. Adding a backup contact ensures reliable emergency response.",
                    action_type="ADD_CONTACT",
                    action_label="Add Backup Contact",
                )
            )

        # 2. Guardian Usage for Late Travel
        guardian_count = await self._db.scalar(
            select(func.count()).where(GuardianSession.user_id == user_id)
        ) or 0
        if guardian_count == 0:
            recommendations.append(
                SafetyRecommendationItem(
                    id="rec_activate_guardian",
                    title="Try Guardian Mode",
                    category="Real-Time Safety",
                    evidence="Guardian Mode monitors your trip continuously with motion and voice watchdog protection.",
                    action_type="ACTIVATE_GUARDIAN",
                    action_label="Turn on Guardian",
                )
            )

        # 3. Check-in Recommendation
        total_journeys = await self._db.scalar(
            select(func.count()).where(Journey.user_id == user_id)
        ) or 0
        if total_journeys >= 3:
            recommendations.append(
                SafetyRecommendationItem(
                    id="rec_safety_checkin",
                    title="Schedule a Safety Check-In",
                    category="Solo Activity",
                    evidence="Set an automated check-in timer when running, walking alone, or meeting new people.",
                    action_type="SET_CHECKIN",
                    action_label="Set Check-In",
                )
            )

        return recommendations
