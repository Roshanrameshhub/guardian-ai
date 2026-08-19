from __future__ import annotations

import asyncio
from datetime import datetime, timedelta, timezone

from app.core.config import get_settings
from app.core.logging import get_logger

settings = get_settings()
log = get_logger("guardian_watchdog")


async def guardian_watchdog_task() -> None:
    """
    Background task that monitors active Guardian sessions.
    
    If a heartbeat is missed beyond the timeout + grace period:
    1. Marks session as 'stale'
    2. Creates a safety event  
    3. Notifies trusted contacts (if configured)
    
    DOES NOT automatically trigger SOS or contact emergency services.
    The user or trusted contacts decide escalation.
    """
    log.info("Guardian watchdog started", 
             timeout=settings.guardian_heartbeat_timeout_seconds,
             grace=settings.guardian_grace_period_seconds)
    
    while True:
        try:
            await _check_stale_sessions()
            await _check_expired_checkins()
        except Exception as exc:
            log.error("Watchdog cycle error", exc_info=exc)
        
        # Check every 30 seconds
        await asyncio.sleep(30)


async def _check_expired_checkins() -> None:
    """Check for active safety check-ins that passed their expiration time."""
    from app.core.database import AsyncSessionLocal
    from app.models.intelligence import CheckInStatus, SafetyCheckIn
    from app.models.notification import Notification, NotificationCategory
    from app.models.safety import SafetyEvent, SafetyEventType, SafetySeverity
    from sqlalchemy import select

    now = datetime.now(tz=timezone.utc)

    async with AsyncSessionLocal() as db:
        expired_checkins = (
            await db.scalars(
                select(SafetyCheckIn).where(
                    SafetyCheckIn.status == CheckInStatus.active,
                    SafetyCheckIn.expires_at <= now,
                )
            )
        ).all()

        for checkin in expired_checkins:
            log.warning(
                "Safety check-in expired without user confirmation",
                checkin_id=checkin.id,
                user_id=checkin.user_id,
            )
            checkin.status = CheckInStatus.expired
            checkin.escalated_at = now

            # Create in-app alert notification
            notif = Notification(
                user_id=checkin.user_id,
                title="Safety Check-In Missed",
                body=f"Your scheduled check-in '{checkin.title}' expired. Please confirm you are safe.",
                category=NotificationCategory.safety,
            )
            db.add(notif)

            # Record safety event
            event = SafetyEvent(
                user_id=checkin.user_id,
                event_type=SafetyEventType.checkin_missed,
                severity=SafetySeverity.medium,
                title=f"Check-In Missed: {checkin.title}",
                subtitle="Scheduled safety check-in window elapsed without user response.",
            )
            db.add(event)

        if expired_checkins:
            await db.commit()
            log.info("Expired check-ins processed", count=len(expired_checkins))


async def _check_stale_sessions() -> None:
    """Check for guardian sessions with stale heartbeats."""
    from app.core.database import AsyncSessionLocal
    from app.models.guardian import GuardianSession, GuardianSessionStatus
    from app.models.safety import SafetyEvent, SafetyEventType, SafetySeverity
    from sqlalchemy import select

    timeout_at = datetime.now(tz=timezone.utc) - timedelta(
        seconds=settings.guardian_heartbeat_timeout_seconds
    )

    async with AsyncSessionLocal() as db:
        # Find active sessions with stale heartbeats
        stale_sessions = (
            await db.scalars(
                select(GuardianSession).where(
                    GuardianSession.status == GuardianSessionStatus.active,
                    GuardianSession.last_heartbeat < timeout_at,
                )
            )
        ).all()

        for session in stale_sessions:
            log.warning(
                "Stale guardian heartbeat detected",
                session_id=session.id,
                user_id=session.user_id,
                last_heartbeat=session.last_heartbeat.isoformat() if session.last_heartbeat else "never",
            )

            # Mark session as stale
            session.status = GuardianSessionStatus.stale

            # Create safety event
            safety_event = SafetyEvent(
                user_id=session.user_id,
                event_type=SafetyEventType.guardian_stale,
                severity=SafetySeverity.medium,
                title="Guardian heartbeat stopped",
                subtitle=(
                    f"No response from device since "
                    f"{session.last_heartbeat.strftime('%I:%M %p') if session.last_heartbeat else 'session start'}. "
                    "Guardian Mode is paused. Check on the user."
                ),
            )
            db.add(safety_event)

            # Create in-app notification
            from app.models.notification import Notification, NotificationCategory
            notif = Notification(
                user_id=session.user_id,
                title="Guardian Mode interrupted",
                body=(
                    "Your Guardian session appears to have stopped. "
                    "If this was unintentional, restart Guardian Mode."
                ),
                category=NotificationCategory.guardian,
            )
            db.add(notif)

            # Queue trusted contact notification (non-escalating)
            await _notify_contacts_watchdog(db, session)

        if stale_sessions:
            await db.commit()
            log.info("Stale sessions processed", count=len(stale_sessions))


async def _notify_contacts_watchdog(db, session) -> None:
    """
    Notify trusted contacts that a guardian session went stale.
    This is informational — NOT an emergency alert.
    Trusted contacts should check on the user, not call emergency services.
    """
    from app.core.config import get_settings
    from app.models.contact import TrustedContact
    from sqlalchemy import select

    # Only notify if SMS is configured
    settings = get_settings()
    if not settings.has_sms:
        log.info(
            "Watchdog contact notification skipped — SMS provider not configured",
            session_id=session.id,
        )
        return

    contacts = (
        await db.scalars(
            select(TrustedContact).where(
                TrustedContact.user_id == session.user_id,
                TrustedContact.emergency_notify_enabled == True,  # noqa: E712
            )
        )
    ).all()

    for contact in contacts:
        # TODO: send informational SMS via configured provider
        log.info(
            "Would notify contact about stale session",
            contact_name=contact.name,
            session_id=session.id,
        )
