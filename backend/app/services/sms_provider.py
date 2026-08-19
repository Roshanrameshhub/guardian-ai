from __future__ import annotations

import httpx
import structlog
from app.core.config import get_settings

logger = structlog.get_logger()
settings = get_settings()


class SmsProvider:
    """Base SMS provider interface."""
    async def send_emergency_sms(
        self,
        to_number: str,
        lat: float | None,
        lng: float | None,
        message: str | None,
        event_id: str,
    ) -> tuple[bool, str]:
        raise NotImplementedError


class TwilioSmsProvider(SmsProvider):
    """Real Twilio SMS delivery engine."""
    def __init__(self) -> None:
        self._settings = settings

    async def send_emergency_sms(
        self,
        to_number: str,
        lat: float | None,
        lng: float | None,
        message: str | None,
        event_id: str,
    ) -> tuple[bool, str]:
        if not self._settings.has_sms:
            return False, "SMS provider not configured (Twilio credentials missing)"

        loc_str = f"https://maps.google.com/?q={lat},{lng}" if (lat and lng) else "Location unavailable"
        body_text = (
            f"GUARDIAN AI EMERGENCY ALERT!\n"
            f"User triggered an SOS alert.\n"
            f"Live GPS: {loc_str}\n"
            f"Message: {message or 'Immediate assistance requested.'}\n"
            f"Event ID: {event_id}"
        )

        url = f"https://api.twilio.com/2010-04-01/Accounts/{self._settings.twilio_account_sid}/Messages.json"
        auth = (self._settings.twilio_account_sid, self._settings.twilio_auth_token)
        data = {
            "From": self._settings.twilio_from_number,
            "To": to_number,
            "Body": body_text,
        }

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.post(url, data=data, auth=auth)
                if resp.status_code in (200, 201):
                    msg_data = resp.json()
                    sid = msg_data.get("sid", "")
                    logger.info("twilio_sms_sent", to=to_number, sid=sid)
                    return True, sid
                else:
                    logger.error("twilio_sms_failed", status=resp.status_code, body=resp.text)
                    return False, f"Twilio HTTP {resp.status_code}: {resp.text}"
        except Exception as e:
            logger.error("twilio_sms_exception", error=str(e))
            return False, str(e)
