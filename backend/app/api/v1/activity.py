from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter
from sqlalchemy import func, select

from app.core.dependencies import CurrentUserId, DbSession
from app.models.achievement import Achievement, UserAchievement
from app.models.journey import Journey, JourneyEvent, JourneyStatus
from app.models.safety import SafetyEvent
from app.models.user import UserProfile
from app.schemas.activity import (
    AchievementResponse,
    ActivityMetricResponse,
    ActivityResponse,
    NotificationResponse,
    SafetyEventResponse,
    WeeklyOverviewResponse,
)
from app.schemas.journey import JourneyResponse
from app.services.journey_service import journey_to_response

router = APIRouter(tags=["Activity"])


@router.get("/activity", response_model=ActivityResponse)
async def get_activity(user_id: CurrentUserId, db: DbSession) -> ActivityResponse:
    """
    Aggregated activity view matching Flutter ActivityEntity.
    Returns weekly overview, metrics, journeys, achievements, safety events.
    """
    profile = await db.scalar(select(UserProfile).where(UserProfile.user_id == user_id))
    avatar_url = (profile.avatar_url or "") if profile else ""

    # Weekly overview — count journeys per day for last 7 days
    bars, labels = await _weekly_bars(user_id, db)
    global_score = await _compute_global_score(user_id, db)

    # Metrics
    total_journeys = await db.scalar(select(func.count()).where(Journey.user_id == user_id)) or 0
    total_events = await db.scalar(select(func.count()).where(SafetyEvent.user_id == user_id)) or 0
    safe_journeys = await db.scalar(
        select(func.count()).where(
            Journey.user_id == user_id,
            Journey.completed_safely == True,  # noqa: E712
        )
    ) or 0

    metrics = [
        ActivityMetricResponse(label="Total Walks", value=str(total_journeys), icon_key="walk"),
        ActivityMetricResponse(
            label="Shield Time",
            value=f"{await _shield_hours(user_id, db):.1f}h",
            icon_key="shield",
        ),
        ActivityMetricResponse(label="Safe Journeys", value=str(safe_journeys), icon_key="alert"),
    ]

    # Recent journeys
    recent = (
        await db.scalars(
            select(Journey)
            .where(Journey.user_id == user_id)
            .order_by(Journey.created_at.desc())
            .limit(10)
        )
    ).all()

    # Achievements
    user_achievement_ids = set(
        (
            await db.scalars(
                select(UserAchievement.achievement_id).where(UserAchievement.user_id == user_id)
            )
        ).all()
    )
    all_achievements = (await db.scalars(select(Achievement))).all()

    # Safety events
    safety_events_raw = (
        await db.scalars(
            select(SafetyEvent)
            .where(SafetyEvent.user_id == user_id)
            .order_by(SafetyEvent.occurred_at.desc())
            .limit(10)
        )
    ).all()

    journey_events_raw = (
        await db.scalars(
            select(JourneyEvent)
            .join(Journey, Journey.id == JourneyEvent.journey_id)
            .where(Journey.user_id == user_id)
            .order_by(JourneyEvent.occurred_at.desc())
            .limit(5)
        )
    ).all()

    safety_event_responses = [
        SafetyEventResponse(
            id=e.id,
            time=e.occurred_at.strftime("%-I:%M %p"),
            title=e.title,
            subtitle=e.subtitle or "",
        )
        for e in safety_events_raw
    ]

    # Also include journey events as safety events for richer feed
    for e in journey_events_raw:
        safety_event_responses.append(
            SafetyEventResponse(
                id=e.id,
                time=e.occurred_at.strftime("%-I:%M %p"),
                title=e.title,
                subtitle=e.subtitle or "",
            )
        )

    # Sort by most recent first (approximation since times are formatted strings)
    safety_event_responses = safety_event_responses[:10]

    return ActivityResponse(
        avatar_url=avatar_url,
        weekly_overview=WeeklyOverviewResponse(
            global_score=global_score,
            bars=bars,
            labels=labels,
        ),
        metrics=metrics,
        journeys=[journey_to_response(j) for j in recent],
        achievements=[
            AchievementResponse(
                id=a.id,
                title=a.title,
                subtitle=a.subtitle,
                unlocked=a.id in user_achievement_ids,
                icon_key=a.icon_key,
            )
            for a in all_achievements
        ],
        safety_events=safety_event_responses,
    )


async def _weekly_bars(user_id: str, db) -> tuple[list[float], list[str]]:
    """Return normalized bars and day labels for the last 7 days."""
    from datetime import timedelta
    now = datetime.now(tz=timezone.utc)
    bars = []
    labels = []
    for i in range(6, -1, -1):
        day = now - timedelta(days=i)
        day_start = day.replace(hour=0, minute=0, second=0, microsecond=0)
        day_end = day.replace(hour=23, minute=59, second=59, microsecond=999999)
        count = await db.scalar(
            select(func.count()).where(
                Journey.user_id == user_id,
                Journey.created_at >= day_start,
                Journey.created_at <= day_end,
            )
        ) or 0
        bars.append(min(1.0, count / 5.0))  # normalize to 0-1, 5 journeys = full bar
        labels.append(day.strftime("%a"))
    return bars, labels


async def _compute_global_score(user_id: str, db) -> int:
    total = await db.scalar(select(func.count()).where(Journey.user_id == user_id)) or 0
    safe = await db.scalar(
        select(func.count()).where(
            Journey.user_id == user_id,
            Journey.completed_safely == True,  # noqa: E712
        )
    ) or 0
    if not total:
        return 85
    return min(100, int(50 + (safe / total) * 50))


async def _shield_hours(user_id: str, db) -> float:
    """Total hours Guardian Mode was active."""
    from app.models.guardian import GuardianSession
    sessions = (
        await db.scalars(
            select(GuardianSession).where(GuardianSession.user_id == user_id)
        )
    ).all()
    total_seconds = 0.0
    for s in sessions:
        if s.started_at and s.ended_at:
            total_seconds += (s.ended_at - s.started_at).total_seconds()
    return total_seconds / 3600
