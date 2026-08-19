from __future__ import annotations

from typing import Any, List, Optional
from pydantic import BaseModel, Field


# ─── Motion Schemas ───────────────────────────────────────────────────────────

class MotionSignalRequest(BaseModel):
    event_type: str = "MOTION_ANOMALY"  # MOTION_ANOMALY / SHAKE / PHONE_DROP / SUDDEN_STOP
    duration_ms: int = Field(default=0, ge=0)
    acceleration_peak: float = Field(default=0.0, ge=0.0)
    rotation_peak: float = Field(default=0.0, ge=0.0)
    sudden_stop: bool = False
    confidence: float = Field(default=0.5, ge=0.0, le=1.0)
    journey_id: Optional[str] = None
    raw_metrics: Optional[dict[str, Any]] = None


class MotionSignalResponse(BaseModel):
    success: bool
    event_id: str
    event_type: str
    evaluated_risk_contribution: float
    confidence_adjusted: float
    message: str


# ─── Voice Schemas ────────────────────────────────────────────────────────────

class VoiceAnalysisRequest(BaseModel):
    transcript_or_text: Optional[str] = ""
    voice_intensity: float = Field(default=0.5, ge=0.0, le=1.0)
    pitch_variance: float = Field(default=0.5, ge=0.0, le=1.0)
    speech_rate_wpm: Optional[int] = None
    duration_ms: int = Field(default=2000, ge=100)
    journey_id: Optional[str] = None


class VoiceDistressResponse(BaseModel):
    signal: str = "VOICE_DISTRESS"
    distress_score: float
    urgency: str  # LOW / MEDIUM / HIGH / CRITICAL
    help_keyword: bool
    repetition_count: int
    voice_intensity: float
    model_confidence: float
    matched_keywords: list[str] = []
    message: str


# ─── Risk Fusion Schemas ──────────────────────────────────────────────────────

class SignalInput(BaseModel):
    type: str  # VOICE_DISTRESS / MOTION_ANOMALY / ROUTE_DEVIATION / PHONE_DROP / SHAKE / SUDDEN_STOP
    score: float = Field(ge=0.0, le=1.0)
    confidence: float = Field(default=1.0, ge=0.0, le=1.0)
    details: Optional[str] = None


class RiskFusionRequest(BaseModel):
    journey_id: Optional[str] = None
    signals: List[SignalInput]
    guardian_mode_active: bool = False
    nearby_safety_incident: bool = False


class RiskSignalDetail(BaseModel):
    type: str
    score: float
    weighted_contribution: float
    explanation: str


class RiskFusionResponse(BaseModel):
    risk_level: str  # LOW / MEDIUM / HIGH / CRITICAL
    risk_score: float
    signals: List[RiskSignalDetail]
    recommended_action: str
    requires_user_prompt: bool
    auto_escalate_prepared: bool


# ─── False Positive Schemas ───────────────────────────────────────────────────

class FalsePositiveFeedbackRequest(BaseModel):
    event_id: Optional[str] = None
    trigger_source: str  # MOTION / VOICE / SHAKE / PHONE_DROP / DEVIATION
    user_response: str = "I_AM_SAFE"  # I_AM_SAFE / FALSE_ALARM / CANCELLED_BY_USER
    voice_score: Optional[float] = None
    motion_score: Optional[float] = None
    route_deviation: bool = False
    notes: Optional[str] = None


class FalsePositiveFeedbackResponse(BaseModel):
    success: bool
    message: str
    motion_profile_adjusted: bool
    current_false_alarm_count: int


# ─── Safety Check-In Schemas ──────────────────────────────────────────────────

class CheckInStartRequest(BaseModel):
    title: str = "Safety Check-In"
    duration_minutes: int = Field(default=15, ge=1, le=240)
    prompt_message: Optional[str] = "Please confirm you have arrived safely."


class CheckInResponse(BaseModel):
    id: str
    title: str
    duration_minutes: int
    status: str
    started_at: str
    expires_at: str
    confirmed_at: Optional[str] = None
    minutes_remaining: int


class CheckInConfirmResponse(BaseModel):
    success: bool
    status: str
    message: str


# ─── Safe Arrival & Route Deviation ───────────────────────────────────────────

class SafeArrivalCheckRequest(BaseModel):
    journey_id: str
    current_lat: float
    current_lng: float
    threshold_meters: float = Field(default=50.0, ge=10.0, le=500.0)


class SafeArrivalCheckResponse(BaseModel):
    journey_id: str
    arrived: bool
    distance_meters: float
    message: str


class RouteDeviationCheckRequest(BaseModel):
    journey_id: str
    current_lat: float
    current_lng: float
    route_points: List[dict[str, float]] = []  # list of {"lat": ..., "lng": ...}


class RouteDeviationCheckResponse(BaseModel):
    journey_id: str
    deviation_status: str  # NORMAL / MINOR / SIGNIFICANT / CONFIRMED / EMERGENCY
    cross_track_distance_meters: float
    deviation_risk_score: float
    message: str


# ─── Location Sharing ─────────────────────────────────────────────────────────

class LocationShareCreateRequest(BaseModel):
    duration_minutes: int = Field(default=60, ge=5, le=1440)
    journey_id: Optional[str] = None


class LocationShareResponse(BaseModel):
    share_token: str
    share_url: str
    expires_at: str
    is_active: bool


# ─── Offline Event Sync ───────────────────────────────────────────────────────

class SyncEventItem(BaseModel):
    idempotency_key: str
    entity_type: str  # SOS / LOCATION / JOURNEY / GUARDIAN / MOTION / CHECKIN
    timestamp: str
    payload: dict[str, Any]


class SyncBatchRequest(BaseModel):
    events: List[SyncEventItem]


class SyncBatchResponse(BaseModel):
    success: bool
    synced_count: int
    duplicate_count: int
    failed_count: int
    message: str


# ─── Recommendations Schemas ──────────────────────────────────────────────────

class SafetyRecommendationItem(BaseModel):
    id: str
    title: str
    category: str
    evidence: str
    action_type: str  # SET_CHECKIN / ACTIVATE_GUARDIAN / ADD_CONTACT / VIEW_ROUTE
    action_label: str
