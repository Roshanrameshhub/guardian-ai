from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import BadRequestError, NotFoundError
from app.models.contact import TrustedContact
from app.models.emergency import (
    EmergencyEvent,
    EmergencyNotification,
    EmergencyStatus,
    NotificationDeliveryStatus,
)
from app.models.guardian import GuardianSession, GuardianSessionStatus
from app.schemas.emergency import EmergencyResponse, SosRequest


class EmergencyService:
    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def trigger_sos(self, user_id: str, req: SosRequest) -> EmergencyResponse:
        """
        SOS lifecycle:
        1. Create emergency event
        2. Load trusted contacts
        3. Create notification records (queued)
        4. Attempt delivery (push/SMS/email)
        5. Update delivery status (never lie about failures)
        6. Return accurate status
        """
        # Check for very recent duplicate SOS (idempotency — within 30 seconds)
        from datetime import timedelta
        cutoff = datetime.now(tz=timezone.utc) - timedelta(seconds=30)
        recent = await self._db.scalar(
            select(EmergencyEvent).where(
                EmergencyEvent.user_id == user_id,
                EmergencyEvent.triggered_at >= cutoff,
                EmergencyEvent.status.notin_([
                    EmergencyStatus.cancelled, EmergencyStatus.resolved
                ]),
            )
        )
        if recent:
            return EmergencyResponse(
                success=True,
                message="Emergency alert already active.",
                event_id=recent.id,
                status=recent.status.value,
            )

        # Get active guardian session
        active_session = await self._db.scalar(
            select(GuardianSession).where(
                GuardianSession.user_id == user_id,
                GuardianSession.status == GuardianSessionStatus.active,
            )
        )

        event = EmergencyEvent(
            user_id=user_id,
            status=EmergencyStatus.processing,
            trigger_source=req.trigger_source,
            lat=req.lat,
            lng=req.lng,
            message=req.message,
            guardian_session_id=active_session.id if active_session else None,
        )
        self._db.add(event)
        await self._db.flush()

        # Load trusted contacts who should receive emergency notifications
        contacts = (
            await self._db.scalars(
                select(TrustedContact).where(
                    TrustedContact.user_id == user_id,
                    TrustedContact.emergency_notify_enabled == True,  # noqa: E712
                )
            )
        ).all()

        # Queue notifications
        notification_records = []
        for contact in contacts:
            if contact.phone:
                # 1. Always queue SMS
                notification_records.append(
                    EmergencyNotification(
                        event_id=event.id,
                        contact_id=contact.id,
                        channel="sms",
                        recipient=contact.phone,
                        delivery_status=NotificationDeliveryStatus.queued,
                    )
                )
                
                # 2. Check if contact is a registered user to queue FCM Push
                from app.models.user import User
                from app.models.notification import DeviceToken
                contact_user = await self._db.scalar(
                    select(User).where(User.phone == contact.phone)
                )
                if contact_user:
                    tokens = await self._db.scalars(
                        select(DeviceToken).where(
                            DeviceToken.user_id == contact_user.id,
                            DeviceToken.is_active == True # noqa: E712
                        )
                    )
                    for t in tokens:
                        notification_records.append(
                            EmergencyNotification(
                                event_id=event.id,
                                contact_id=contact.id,
                                channel="push",
                                recipient=t.token,
                                delivery_status=NotificationDeliveryStatus.queued,
                            )
                        )

        self._db.add_all(notification_records)

        event.status = EmergencyStatus.notifications_queued
        await self._db.flush()


        # Attempt delivery (async, non-blocking)
        # In production this would be delegated to a background worker
        delivery_result = await self._attempt_delivery(event, notification_records, req)

        event.status = EmergencyStatus.active
        await self._db.commit()
        await self._db.refresh(event)

        return EmergencyResponse(
            success=True,
            message=delivery_result,
            event_id=event.id,
            status=event.status.value,
        )

    async def cancel_sos(self, user_id: str, event_id: str) -> EmergencyResponse:
        event = await self._db.get(EmergencyEvent, event_id)
        if not event:
            raise NotFoundError("Emergency event not found.")
        if event.user_id != user_id:
            raise BadRequestError("Not authorized.")
        if event.status in (EmergencyStatus.cancelled, EmergencyStatus.resolved):
            return EmergencyResponse(
                success=True,
                message="Emergency already resolved.",
                event_id=event.id,
                status=event.status.value,
            )
        event.status = EmergencyStatus.cancelled
        event.cancelled_at = datetime.now(tz=timezone.utc)
        await self._db.commit()
        return EmergencyResponse(
            success=True,
            message="Emergency alert cancelled.",
            event_id=event.id,
            status=event.status.value,
        )

    async def get_event(self, user_id: str, event_id: str) -> EmergencyResponse:
        event = await self._db.get(EmergencyEvent, event_id)
        if not event:
            raise NotFoundError("Emergency event not found.")
        if event.user_id != user_id:
            raise BadRequestError("Not authorized.")
        return EmergencyResponse(
            success=True,
            message="",
            event_id=event.id,
            status=event.status.value,
        )

    async def _attempt_delivery(
        self,
        event: EmergencyEvent,
        notifications: list[EmergencyNotification],
        req: SosRequest,
    ) -> str:
        """
        Attempt to deliver notifications.
        Updates delivery_status honestly — never claims success when failed.
        """
        from app.core.config import get_settings
        settings = get_settings()

        delivered = 0
        failed = 0

        if not notifications:
            return "SOS recorded. No emergency contacts configured."

        from app.services.sms_provider import TwilioSmsProvider
        from app.services.fcm_provider import FcmProvider
        
        sms_provider = TwilioSmsProvider()
        fcm_provider = FcmProvider()

        for notif in notifications:
            success = False
            
            if notif.channel == "sms":
                if settings.has_sms:
                    success, reason_or_sid = await sms_provider.send_emergency_sms(
                        to_number=notif.recipient,
                        lat=req.lat,
                        lng=req.lng,
                        message=req.message,
                        event_id=event.id,
                    )
                    if not success:
                        notif.failure_reason = reason_or_sid
                else:
                    # Log that SMS is not configured — do NOT claim it was sent
                    notif.failure_reason = "SMS provider not configured (Twilio credentials required)"
            
            elif notif.channel == "push":
                if settings.has_push:
                    success, reason = await fcm_provider.send_emergency_push(
                        token=notif.recipient,
                        title="EMERGENCY SOS",
                        body=f"{req.message or 'Needs help immediately.'} Location attached.",
                        data={
                            "event_id": event.id,
                            "lat": str(req.lat) if req.lat else "",
                            "lng": str(req.lng) if req.lng else "",
                            "type": "sos"
                        }
                    )
                    if not success:
                        notif.failure_reason = reason
                else:
                    notif.failure_reason = "FCM push not configured (Firebase service account required)"


            if success:
                notif.delivery_status = NotificationDeliveryStatus.sent
                notif.sent_at = datetime.now(tz=timezone.utc)
                delivered += 1
            else:
                notif.delivery_status = NotificationDeliveryStatus.failed
                failed += 1

        if delivered > 0 and failed == 0:
            return f"Emergency alert sent to {delivered} contact(s)."
        if delivered > 0:
            return f"Emergency alert sent to {delivered} contact(s). {failed} delivery failed."
        return (
            "SOS recorded in system. "
            "Notification delivery requires provider configuration. "
            f"({len(notifications)} contact(s) not notified)"
        )


