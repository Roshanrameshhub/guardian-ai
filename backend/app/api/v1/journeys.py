from __future__ import annotations

from fastapi import APIRouter

from app.core.dependencies import CurrentUserId, DbSession
from app.schemas.journey import (
    JourneyListResponse,
    JourneyResponse,
    RerouteRequest,
    StartJourneyRequest,
    StationaryCheckRequest,
    StationaryCheckResponse,
)
from app.schemas.common import ApiMessageResponse
from app.services.journey_service import JourneyService, journey_to_response

router = APIRouter(tags=["Journeys"])


# ─── Match Flutter ApiConstants paths exactly ─────────────────────────────────

@router.get("/journeys", response_model=JourneyListResponse)
async def list_journeys(user_id: CurrentUserId, db: DbSession) -> JourneyListResponse:
    """List journey history for the current user."""
    svc = JourneyService(db)
    journeys = await svc.list_journeys(user_id)
    items = [journey_to_response(j) for j in journeys]
    return JourneyListResponse(journeys=items, total=len(items))


@router.get("/journey/{journey_id}", response_model=JourneyResponse)
async def get_journey(
    journey_id: str, user_id: CurrentUserId, db: DbSession
) -> JourneyResponse:
    """Get a single journey by ID."""
    journey = await JourneyService(db).get_journey(user_id, journey_id)
    return journey_to_response(journey)


@router.post("/journey/start", response_model=JourneyResponse, status_code=201)
async def start_journey(
    req: StartJourneyRequest, user_id: CurrentUserId, db: DbSession
) -> JourneyResponse:
    """Start a new journey and begin tracking."""
    journey = await JourneyService(db).start_journey(user_id, req)
    return journey_to_response(journey)


@router.post("/journey/stop/{journey_id}", response_model=JourneyResponse)
async def stop_journey(
    journey_id: str, user_id: CurrentUserId, db: DbSession
) -> JourneyResponse:
    """Stop and complete a journey."""
    journey = await JourneyService(db).stop_journey(user_id, journey_id)
    return journey_to_response(journey)


@router.delete("/journey/{journey_id}", response_model=ApiMessageResponse)
async def delete_journey(
    journey_id: str, user_id: CurrentUserId, db: DbSession
) -> ApiMessageResponse:
    """Delete a journey record."""
    await JourneyService(db).delete_journey(user_id, journey_id)
    return ApiMessageResponse(success=True, message="Journey deleted.")


@router.post("/journey/stationary-check", response_model=StationaryCheckResponse)
async def check_journey_stationary(
    req: StationaryCheckRequest, user_id: CurrentUserId, db: DbSession
) -> StationaryCheckResponse:
    """Check for unexpected prolonged stops vs normal traffic delays."""
    return await JourneyService(db).check_stationary(user_id, req)


@router.post("/journey/reroute")
async def reroute_journey(
    req: RerouteRequest, user_id: CurrentUserId, db: DbSession
) -> dict:
    """Calculate safety-aware route alternative when deviating from scheduled path."""
    return await JourneyService(db).calculate_reroute(user_id, req)
