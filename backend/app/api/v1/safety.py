from __future__ import annotations

from fastapi import APIRouter, Query

from app.core.dependencies import CurrentUserId, DbSession
from app.schemas.common import AreaSafetyResponse, SafetyEventResponse, ApiMessageResponse

router = APIRouter(tags=["Safety"])


@router.get("/safety/score")
async def get_safety_score(user_id: CurrentUserId, db: DbSession) -> dict:
    """
    Return the current user's safety score with contributing factors.
    Never claims certainty — returns confidence and data availability.
    """
    from sqlalchemy import func, select
    from app.models.journey import Journey

    total = await db.scalar(select(func.count()).where(Journey.user_id == user_id)) or 0
    safe = await db.scalar(
        select(func.count()).where(
            Journey.user_id == user_id, Journey.completed_safely == True
        )
    ) or 0

    score = min(100, int(50 + (safe / total * 50))) if total else 85
    label = "Excellent" if score >= 90 else "Good" if score >= 75 else "Moderate" if score >= 55 else "Low"

    return {
        "score": score,
        "label": label,
        "factors": {
            "total_journeys": total,
            "safe_journeys": safe,
            "safety_rate": round(safe / total, 2) if total else 1.0,
        },
        "confidence": "high" if total >= 5 else "low",
        "data_note": "Based on journey history. More journeys = more accurate score.",
    }


@router.get("/safety/events", response_model=list[SafetyEventResponse])
async def list_safety_events(
    user_id: CurrentUserId,
    db: DbSession,
    radius_km: float = Query(5.0, le=50.0),
) -> list[SafetyEventResponse]:
    """List safety events for the user. External data only when provider configured."""
    from sqlalchemy import select
    from app.models.safety import SafetyEvent
    from app.core.config import get_settings
    import datetime

    settings = get_settings()

    if settings.safety_data_api_key:
        # TODO: call external SafetyDataProvider
        pass

    # Return user-specific safety events from DB
    events = (
        await db.scalars(
            select(SafetyEvent)
            .where(SafetyEvent.user_id == user_id)
            .order_by(SafetyEvent.occurred_at.desc())
            .limit(20)
        )
    ).all()

    return [
        SafetyEventResponse(
            id=e.id,
            time=e.occurred_at.strftime("%-I:%M %p"),
            title=e.title,
            subtitle=e.subtitle or "",
        )
        for e in events
    ]


@router.get("/safety/statistics")
async def get_safety_statistics(user_id: CurrentUserId, db: DbSession) -> dict:
    """Safety statistics for analytics."""
    from sqlalchemy import func, select
    from app.models.journey import Journey
    from app.models.emergency import EmergencyEvent

    total_journeys = await db.scalar(select(func.count()).where(Journey.user_id == user_id)) or 0
    emergency_count = await db.scalar(
        select(func.count()).where(EmergencyEvent.user_id == user_id)
    ) or 0

    return {
        "total_journeys": total_journeys,
        "emergency_events": emergency_count,
        "summary": f"{total_journeys} journeys tracked by Guardian AI.",
    }
