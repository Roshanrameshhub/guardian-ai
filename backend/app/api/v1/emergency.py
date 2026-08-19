from __future__ import annotations

from fastapi import APIRouter

from app.core.dependencies import CurrentUserId, DbSession
from app.schemas.emergency import EmergencyCancelRequest, EmergencyResponse, SosRequest
from app.services.emergency_service import EmergencyService

router = APIRouter(tags=["Emergency"])


@router.post("/emergency/sos", response_model=EmergencyResponse, status_code=201)
async def trigger_sos(
    req: SosRequest, user_id: CurrentUserId, db: DbSession
) -> EmergencyResponse:
    """
    Trigger an emergency SOS alert.
    Notifies trusted contacts via configured channels.
    Response includes actual delivery status — never claims success when delivery failed.
    """
    return await EmergencyService(db).trigger_sos(user_id, req)


@router.get("/emergency/{event_id}", response_model=EmergencyResponse)
async def get_emergency(
    event_id: str, user_id: CurrentUserId, db: DbSession
) -> EmergencyResponse:
    """Get the current state of an emergency event."""
    return await EmergencyService(db).get_event(user_id, event_id)


@router.post("/emergency/{event_id}/cancel", response_model=EmergencyResponse)
async def cancel_emergency(
    event_id: str,
    req: EmergencyCancelRequest,
    user_id: CurrentUserId,
    db: DbSession,
) -> EmergencyResponse:
    """Cancel an active emergency alert."""
    return await EmergencyService(db).cancel_sos(user_id, event_id)
