from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone
from typing import List

from fastapi import APIRouter

from app.core.dependencies import CurrentUserId, DbSession
from app.models.intelligence import LocationShareSession
from app.schemas.intelligence import (
    CheckInConfirmResponse,
    CheckInResponse,
    CheckInStartRequest,
    FalsePositiveFeedbackRequest,
    FalsePositiveFeedbackResponse,
    LocationShareCreateRequest,
    LocationShareResponse,
    MotionSignalRequest,
    MotionSignalResponse,
    RiskFusionRequest,
    RiskFusionResponse,
    RouteDeviationCheckRequest,
    RouteDeviationCheckResponse,
    SafeArrivalCheckRequest,
    SafeArrivalCheckResponse,
    SafetyRecommendationItem,
    SyncBatchRequest,
    SyncBatchResponse,
    VoiceAnalysisRequest,
    VoiceDistressResponse,
)
from app.services.checkin_service import CheckInService
from app.services.deviation_service import DeviationService
from app.services.false_positive_service import FalsePositiveService
from app.services.motion_service import MotionSignalService
from app.services.recommendation_service import RecommendationService
from app.services.risk_fusion_service import RiskFusionService
from app.services.safe_arrival_service import SafeArrivalService
from app.services.sync_service import OfflineSyncService
from app.services.voice.distress_service import VoiceDistressService

router = APIRouter(tags=["Safety Intelligence"])


# ─── Signals: Motion & Voice ──────────────────────────────────────────────────

@router.post("/signals/motion", response_model=MotionSignalResponse)
async def process_motion_signal(
    req: MotionSignalRequest, user_id: CurrentUserId, db: DbSession
) -> MotionSignalResponse:
    """Process windowed motion sensor anomalies (accelerometer/gyroscope features)."""
    return await MotionSignalService(db).process_motion_signal(user_id, req)


@router.post("/signals/voice", response_model=VoiceDistressResponse)
async def analyze_voice_distress(
    req: VoiceAnalysisRequest, user_id: CurrentUserId, db: DbSession
) -> VoiceDistressResponse:
    """Analyze vocal distress markers, repetition, and urgency keywords."""
    return await VoiceDistressService(db).analyze_voice(user_id, req)


# ─── Multimodal Risk Fusion ───────────────────────────────────────────────────

@router.post("/risk/fuse", response_model=RiskFusionResponse)
async def fuse_multimodal_risk(
    req: RiskFusionRequest, user_id: CurrentUserId, db: DbSession
) -> RiskFusionResponse:
    """Fuse multi-sensor signals (Voice, Motion, Deviation, State) into unified risk rating."""
    return await RiskFusionService(db).fuse_signals(user_id, req)


# ─── False Positive Analytics & Learning ──────────────────────────────────────

@router.post("/safety/false-positive", response_model=FalsePositiveFeedbackResponse)
async def record_false_positive_feedback(
    req: FalsePositiveFeedbackRequest, user_id: CurrentUserId, db: DbSession
) -> FalsePositiveFeedbackResponse:
    """Log user dismissal ("I'm Safe") and tune personalized motion baseline."""
    return await FalsePositiveService(db).record_feedback(user_id, req)


# ─── Safe Arrival & Route Deviation ───────────────────────────────────────────

@router.post("/safety/safe-arrival", response_model=SafeArrivalCheckResponse)
async def check_safe_arrival(
    req: SafeArrivalCheckRequest, user_id: CurrentUserId, db: DbSession
) -> SafeArrivalCheckResponse:
    """Evaluate distance threshold against journey destination."""
    return await SafeArrivalService(db).check_arrival(user_id, req)


@router.post("/safety/route-deviation", response_model=RouteDeviationCheckResponse)
async def evaluate_route_deviation(
    req: RouteDeviationCheckRequest, user_id: CurrentUserId, db: DbSession
) -> RouteDeviationCheckResponse:
    """Evaluate cross-track distance variance from planned route polyline."""
    return await DeviationService(db).evaluate_deviation(user_id, req)


# ─── Safety Check-Ins ─────────────────────────────────────────────────────────

@router.post("/checkins/start", response_model=CheckInResponse, status_code=201)
async def start_safety_checkin(
    req: CheckInStartRequest, user_id: CurrentUserId, db: DbSession
) -> CheckInResponse:
    """Start an active safety check-in countdown timer."""
    return await CheckInService(db).start_checkin(user_id, req)


@router.post("/checkins/{checkin_id}/confirm", response_model=CheckInConfirmResponse)
async def confirm_safety_checkin(
    checkin_id: str, user_id: CurrentUserId, db: DbSession
) -> CheckInConfirmResponse:
    """Confirm safety check-in before expiration."""
    return await CheckInService(db).confirm_checkin(user_id, checkin_id)


@router.post("/checkins/{checkin_id}/cancel", response_model=CheckInConfirmResponse)
async def cancel_safety_checkin(
    checkin_id: str, user_id: CurrentUserId, db: DbSession
) -> CheckInConfirmResponse:
    """Cancel an active check-in session."""
    return await CheckInService(db).cancel_checkin(user_id, checkin_id)


@router.get("/checkins", response_model=List[CheckInResponse])
async def list_safety_checkins(
    user_id: CurrentUserId, db: DbSession
) -> List[CheckInResponse]:
    """List recent safety check-in history."""
    return await CheckInService(db).list_checkins(user_id)


# ─── Live Location Sharing ────────────────────────────────────────────────────

@router.post("/location/share", response_model=LocationShareResponse)
async def create_location_share(
    req: LocationShareCreateRequest, user_id: CurrentUserId, db: DbSession
) -> LocationShareResponse:
    """Create a temporary authenticated live location sharing session."""
    token = str(uuid.uuid4()).replace("-", "")[:16]
    expires_at = datetime.now(tz=timezone.utc) + timedelta(minutes=req.duration_minutes)

    session = LocationShareSession(
        user_id=user_id,
        share_token=token,
        journey_id=req.journey_id,
        expires_at=expires_at,
        is_active=True,
    )
    db.add(session)
    await db.commit()

    return LocationShareResponse(
        share_token=token,
        share_url=f"https://guardian.ai/track/{token}",
        expires_at=expires_at.isoformat(),
        is_active=True,
    )


# ─── Offline Event Batch Sync ─────────────────────────────────────────────────

@router.post("/sync/events", response_model=SyncBatchResponse)
async def sync_offline_events(
    req: SyncBatchRequest, user_id: CurrentUserId, db: DbSession
) -> SyncBatchResponse:
    """Idempotently ingest batch event logs queued while device was offline."""
    return await OfflineSyncService(db).process_sync_batch(user_id, req)


# ─── Personalized Safety Recommendations ──────────────────────────────────────

@router.get("/safety/recommendations", response_model=List[SafetyRecommendationItem])
async def get_safety_recommendations(
    user_id: CurrentUserId, db: DbSession
) -> List[SafetyRecommendationItem]:
    """Retrieve evidence-based personalized safety suggestions."""
    return await RecommendationService(db).get_personalized_recommendations(user_id)
