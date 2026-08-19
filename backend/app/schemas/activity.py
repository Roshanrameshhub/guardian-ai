from __future__ import annotations

from pydantic import BaseModel


class NotificationResponse(BaseModel):
    """Matches Flutter NotificationEntity."""
    id: str
    title: str
    body: str
    time_label: str
    is_read: bool
    category: str | None = None

    model_config = {"from_attributes": True}


class WeeklyOverviewResponse(BaseModel):
    global_score: int
    bars: list[float]
    labels: list[str]


class ActivityMetricResponse(BaseModel):
    label: str
    value: str
    icon_key: str


class AchievementResponse(BaseModel):
    """Matches Flutter AchievementEntity."""
    id: str
    title: str
    subtitle: str
    unlocked: bool
    icon_key: str

    model_config = {"from_attributes": True}


class SafetyEventResponse(BaseModel):
    """Matches Flutter SafetyEventEntity."""
    id: str
    time: str
    title: str
    subtitle: str


class ActivityResponse(BaseModel):
    """Matches Flutter ActivityEntity."""
    avatar_url: str
    weekly_overview: WeeklyOverviewResponse
    metrics: list[ActivityMetricResponse]
    journeys: list
    achievements: list[AchievementResponse]
    safety_events: list[SafetyEventResponse]
