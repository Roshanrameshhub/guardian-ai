from __future__ import annotations

from datetime import datetime, timezone
from fastapi import APIRouter
from pydantic import BaseModel
from sqlalchemy import select, update

from app.core.dependencies import CurrentUserId, DbSession
from app.models.notification import Notification, DeviceToken
from app.schemas.activity import NotificationResponse
from app.schemas.common import ApiMessageResponse

router = APIRouter(tags=["Notifications"])


class DeviceTokenRegisterRequest(BaseModel):
    token: str
    platform: str = "android"
    app_version: str | None = "1.2.0"


@router.get("/notifications", response_model=list[NotificationResponse])
async def list_notifications(
    user_id: CurrentUserId, db: DbSession
) -> list[NotificationResponse]:
    """List all notifications for the current user, newest first."""
    notifications = (
        await db.scalars(
            select(Notification)
            .where(Notification.user_id == user_id)
            .order_by(Notification.created_at.desc())
            .limit(50)
        )
    ).all()

    now = datetime.now(tz=timezone.utc)

    def _time_label(created_at: datetime) -> str:
        delta = now - (created_at if created_at.tzinfo else created_at.replace(tzinfo=timezone.utc))
        secs = int(delta.total_seconds())
        if secs < 60:
            return f"{secs}s ago"
        if secs < 3600:
            return f"{secs // 60}m ago"
        if secs < 86400:
            return f"{secs // 3600}h ago"
        return f"{secs // 86400}d ago"

    return [
        NotificationResponse(
            id=n.id,
            title=n.title,
            body=n.body,
            time_label=_time_label(n.created_at),
            is_read=n.is_read,
            category=n.category.value if n.category else None,
        )
        for n in notifications
    ]


@router.post("/notifications/device-token", response_model=ApiMessageResponse)
async def register_device_token(
    request: DeviceTokenRegisterRequest,
    user_id: CurrentUserId,
    db: DbSession,
) -> ApiMessageResponse:
    """Register or refresh real FCM device push token."""
    existing = await db.scalar(
        select(DeviceToken).where(DeviceToken.token == request.token)
    )
    if existing:
        existing.user_id = user_id
        existing.platform = request.platform
        existing.app_version = request.app_version
        existing.is_active = True
        existing.last_active_at = datetime.now(tz=timezone.utc)
    else:
        new_token = DeviceToken(
            user_id=user_id,
            token=request.token,
            platform=request.platform,
            app_version=request.app_version,
            is_active=True,
        )
        db.add(new_token)

    await db.commit()
    return ApiMessageResponse(success=True, message="Device token registered successfully.")


@router.patch("/notifications/{notification_id}/read", response_model=ApiMessageResponse)
async def mark_notification_read(
    notification_id: str, user_id: CurrentUserId, db: DbSession
) -> ApiMessageResponse:
    """Mark a notification as read."""
    from app.core.exceptions import ForbiddenError, NotFoundError

    notif = await db.get(Notification, notification_id)
    if not notif:
        raise NotFoundError("Notification not found.")
    if notif.user_id != user_id:
        raise ForbiddenError()
    notif.is_read = True
    await db.commit()
    return ApiMessageResponse(success=True, message="Marked as read.")


@router.post("/notifications/read-all", response_model=ApiMessageResponse)
async def mark_all_read(user_id: CurrentUserId, db: DbSession) -> ApiMessageResponse:
    """Mark all notifications as read."""
    await db.execute(
        update(Notification)
        .where(Notification.user_id == user_id, Notification.is_read == False)  # noqa: E712
        .values(is_read=True)
    )
    await db.commit()
    return ApiMessageResponse(success=True, message="All notifications marked as read.")


@router.delete("/notifications/{notification_id}", response_model=ApiMessageResponse)
async def delete_notification(
    notification_id: str, user_id: CurrentUserId, db: DbSession
) -> ApiMessageResponse:
    """Delete a notification."""
    from app.core.exceptions import ForbiddenError, NotFoundError

    notif = await db.get(Notification, notification_id)
    if not notif:
        raise NotFoundError("Notification not found.")
    if notif.user_id != user_id:
        raise ForbiddenError()
    await db.delete(notif)
    await db.commit()
    return ApiMessageResponse(success=True, message="Notification deleted.")
