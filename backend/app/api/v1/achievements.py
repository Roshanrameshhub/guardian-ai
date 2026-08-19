from __future__ import annotations

from fastapi import APIRouter
from sqlalchemy import select

from app.core.dependencies import CurrentUserId, DbSession
from app.models.achievement import Achievement, UserAchievement
from app.schemas.activity import AchievementResponse
from app.schemas.common import ApiMessageResponse

router = APIRouter(tags=["Achievements"])

# ─── Seed data — loaded once on first use ─────────────────────────────────────
_SEED_ACHIEVEMENTS = [
    {"key": "first_journey", "title": "First Journey", "subtitle": "Completed your first safe journey", "icon_key": "shield"},
    {"key": "night_sentinel", "title": "Night Sentinel", "subtitle": "10 night walks secured", "icon_key": "ribbon"},
    {"key": "swift_responder", "title": "Swift Responder", "subtitle": "Check-in within 5 seconds", "icon_key": "check"},
    {"key": "first_guard", "title": "First Guard", "subtitle": "Set up your Trusted Circle", "icon_key": "shield"},
    {"key": "guardian_user", "title": "Guardian Mode User", "subtitle": "Used Guardian Mode 5 times", "icon_key": "ribbon"},
    {"key": "safe_10", "title": "Safety Streak", "subtitle": "10 journeys completed safely", "icon_key": "check"},
    {"key": "trusted_network", "title": "Trusted Network", "subtitle": "Added 3+ trusted contacts", "icon_key": "ribbon"},
    {"key": "emergency_ready", "title": "Emergency Preparedness", "subtitle": "SOS configured and tested", "icon_key": "shield"},
]


async def _ensure_achievements_seeded(db) -> None:
    """Seed the achievements table if empty."""
    count = await db.scalar(select(Achievement).limit(1))
    if count:
        return
    for data in _SEED_ACHIEVEMENTS:
        db.add(Achievement(**data))
    await db.commit()


@router.get("/achievements", response_model=list[AchievementResponse])
async def list_achievements(
    user_id: CurrentUserId, db: DbSession
) -> list[AchievementResponse]:
    """List all achievements with unlock status for the current user."""
    await _ensure_achievements_seeded(db)

    # Check which user has unlocked
    unlocked_ids = set(
        (
            await db.scalars(
                select(UserAchievement.achievement_id).where(UserAchievement.user_id == user_id)
            )
        ).all()
    )

    # Check for newly earned achievements
    await _check_and_award_achievements(user_id, db, unlocked_ids)

    # Reload after potential new unlocks
    unlocked_ids = set(
        (
            await db.scalars(
                select(UserAchievement.achievement_id).where(UserAchievement.user_id == user_id)
            )
        ).all()
    )

    achievements = (await db.scalars(select(Achievement))).all()
    return [
        AchievementResponse(
            id=a.id,
            title=a.title,
            subtitle=a.subtitle,
            unlocked=a.id in unlocked_ids,
            icon_key=a.icon_key,
        )
        for a in achievements
    ]


async def _check_and_award_achievements(user_id: str, db, existing_unlocked: set) -> None:
    """Award achievements based on actual activity data."""
    from sqlalchemy import func
    from app.models.journey import Journey
    from app.models.guardian import GuardianSession
    from app.models.contact import TrustedContact
    import datetime

    all_achievements = {a.key: a for a in (await db.scalars(select(Achievement))).all()}

    journey_count = await db.scalar(select(func.count()).where(Journey.user_id == user_id)) or 0
    safe_count = await db.scalar(
        select(func.count()).where(Journey.user_id == user_id, Journey.completed_safely == True)
    ) or 0
    guardian_count = await db.scalar(
        select(func.count()).where(GuardianSession.user_id == user_id)
    ) or 0
    contact_count = await db.scalar(
        select(func.count()).where(TrustedContact.user_id == user_id)
    ) or 0

    to_award = []
    if journey_count >= 1 and "first_journey" in all_achievements:
        to_award.append(all_achievements["first_journey"])
    if safe_count >= 10 and "safe_10" in all_achievements:
        to_award.append(all_achievements["safe_10"])
    if guardian_count >= 5 and "guardian_user" in all_achievements:
        to_award.append(all_achievements["guardian_user"])
    if contact_count >= 3 and "trusted_network" in all_achievements:
        to_award.append(all_achievements["trusted_network"])

    for achievement in to_award:
        if achievement.id not in existing_unlocked:
            db.add(UserAchievement(user_id=user_id, achievement_id=achievement.id))

    if to_award:
        await db.commit()
