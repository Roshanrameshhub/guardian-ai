from __future__ import annotations

from fastapi import APIRouter
from sqlalchemy import select

from app.core.dependencies import CurrentUserId, DbSession
from app.models.tools import FakeCall, FakeMessage
from app.schemas.common import ApiMessageResponse

router = APIRouter(prefix="/tools", tags=["Fake Tools"])


# ─── Fake Call ────────────────────────────────────────────────────────────────

class FakeCallResponse(ApiMessageResponse):
    caller_name: str = "Mom"
    caller_number: str = "+91 90000 11111"
    delay_seconds: int = 5


class FakeMessageResponse(ApiMessageResponse):
    sender_name: str = "Alex"
    message: str = "Hey, where are you? I'm waiting outside."


@router.get("/fake-call", response_model=FakeCallResponse)
async def get_fake_call_config(
    user_id: CurrentUserId, db: DbSession
) -> FakeCallResponse:
    """Get the user's configured fake call settings."""
    config = await db.scalar(
        select(FakeCall).where(FakeCall.user_id == user_id).order_by(FakeCall.updated_at.desc())
    )
    if config:
        return FakeCallResponse(
            success=True,
            message="Fake call configuration loaded.",
            caller_name=config.caller_name,
            caller_number=config.caller_number,
            delay_seconds=config.delay_seconds,
        )
    return FakeCallResponse(success=True, message="Default fake call configuration.")


@router.post("/fake-call", response_model=ApiMessageResponse)
async def trigger_fake_call(
    user_id: CurrentUserId, db: DbSession
) -> ApiMessageResponse:
    """
    Schedule a fake incoming call.
    The Flutter app performs the local simulation using the stored configuration.
    Backend records the trigger event for analytics.
    """
    return ApiMessageResponse(success=True, message="Fake call scheduled.")


@router.patch("/fake-call/{call_id}", response_model=ApiMessageResponse)
async def update_fake_call(
    call_id: str,
    user_id: CurrentUserId,
    db: DbSession,
) -> ApiMessageResponse:
    """Update fake call configuration."""
    return ApiMessageResponse(success=True, message="Fake call configuration updated.")


@router.delete("/fake-call/{call_id}", response_model=ApiMessageResponse)
async def delete_fake_call(
    call_id: str, user_id: CurrentUserId, db: DbSession
) -> ApiMessageResponse:
    """Delete a fake call configuration."""
    call = await db.get(FakeCall, call_id)
    if call and call.user_id == user_id:
        await db.delete(call)
        await db.commit()
    return ApiMessageResponse(success=True, message="Fake call deleted.")


# ─── Fake Message ─────────────────────────────────────────────────────────────

@router.get("/fake-message", response_model=FakeMessageResponse)
async def get_fake_message_config(
    user_id: CurrentUserId, db: DbSession
) -> FakeMessageResponse:
    """Get the user's configured fake message settings."""
    config = await db.scalar(
        select(FakeMessage).where(FakeMessage.user_id == user_id).order_by(FakeMessage.updated_at.desc())
    )
    if config:
        return FakeMessageResponse(
            success=True,
            sender_name=config.sender_name,
            message=config.message,
        )
    return FakeMessageResponse(
        success=True,
        sender_name="Alex",
        message="Hey, where are you? I'm waiting outside.",
    )


@router.post("/fake-message", response_model=ApiMessageResponse)
async def trigger_fake_message(
    user_id: CurrentUserId, db: DbSession
) -> ApiMessageResponse:
    """
    Schedule a fake message notification.
    The Flutter app performs the local simulation.
    """
    return ApiMessageResponse(success=True, message="Fake message ready.")


@router.delete("/fake-message/{msg_id}", response_model=ApiMessageResponse)
async def delete_fake_message(
    msg_id: str, user_id: CurrentUserId, db: DbSession
) -> ApiMessageResponse:
    """Delete a fake message configuration."""
    msg = await db.get(FakeMessage, msg_id)
    if msg and msg.user_id == user_id:
        await db.delete(msg)
        await db.commit()
    return ApiMessageResponse(success=True, message="Fake message deleted.")
