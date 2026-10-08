from datetime import datetime, timezone
import httpx
import structlog

from app.core.config import get_settings

logger = structlog.get_logger("telegram_provider")


class TelegramProvider:
    def __init__(self):
        self._settings = get_settings()

    async def send_emergency_alert(
        self,
        chat_id: str,
        contact_name: str,
        lat: float,
        lng: float,
        reason: str | None = None,
        battery_level: int | None = None,
    ) -> tuple[bool, str]:
        """
        Dispatches real-time emergency SOS alert with live GPS coordinates to a Telegram chat.
        Reads TELEGRAM_BOT_TOKEN exclusively from backend environment settings.
        """
        if not self._settings.has_telegram:
            return False, "Telegram Bot not configured (TELEGRAM_BOT_TOKEN missing)"

        clean_chat_id = str(chat_id).strip()
        if not clean_chat_id:
            return False, "Chat ID is empty"

        try:
            bot_token = self._settings.telegram_bot_token.strip()
            url = f"https://api.telegram.org/bot{bot_token}/sendMessage"

            maps_link = f"https://maps.google.com/?q={lat},{lng}"
            now_str = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
            battery_str = f"{battery_level}%" if battery_level is not None else "Unknown"
            trigger_reason = reason or "Emergency SOS Triggered"

            text = (
                "🚨 *GUARDIAN AI EMERGENCY SOS* 🚨\n\n"
                f"⚠️ *Alert for Trusted Contact:* {contact_name}\n"
                f"⚡ *Trigger Source:* {trigger_reason}\n"
                f"🔋 *Battery Level:* {battery_str}\n"
                f"🕒 *Time:* {now_str}\n\n"
                f"📍 *Live GPS Location:*\n{maps_link}\n\n"
                "👉 Please contact the user immediately or alert local authorities if needed."
            )

            payload = {
                "chat_id": clean_chat_id,
                "text": text,
                "parse_mode": "Markdown",
                "disable_web_page_preview": False,
            }

            async with httpx.AsyncClient(timeout=15.0) as client:
                resp = await client.post(url, json=payload)
                if resp.status_code == 200:
                    logger.info("telegram_emergency_alert_sent", chat_id=clean_chat_id, contact=contact_name)
                    return True, f"Sent to Telegram chat {clean_chat_id}"
                else:
                    err = f"Telegram API error {resp.status_code}: {resp.text}"
                    logger.warning("telegram_send_failed", error=err)
                    return False, err
        except Exception as e:
            logger.error("telegram_send_exception", error=str(e))
            return False, str(e)

    async def send_test_ping(self, chat_id: str, contact_name: str) -> tuple[bool, str]:
        """
        Sends a verification test ping to confirm Telegram bot connectivity.
        Reads TELEGRAM_BOT_TOKEN exclusively from backend environment settings.
        """
        if not self._settings.has_telegram:
            return False, "Telegram Bot not configured (TELEGRAM_BOT_TOKEN missing)"

        clean_chat_id = str(chat_id).strip()
        if not clean_chat_id:
            return False, "Chat ID is empty"

        try:
            bot_token = self._settings.telegram_bot_token.strip()
            url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
            text = (
                "🛡️ *Guardian AI — Telegram Connection Verified*\n\n"
                f"Hello {contact_name}! This Telegram chat is linked to Guardian AI.\n"
                "You will automatically receive instant SOS alerts with live GPS location whenever an emergency is detected."
            )
            payload = {
                "chat_id": clean_chat_id,
                "text": text,
                "parse_mode": "Markdown",
            }

            async with httpx.AsyncClient(timeout=15.0) as client:
                resp = await client.post(url, json=payload)
                if resp.status_code == 200:
                    logger.info("telegram_test_ping_sent", chat_id=clean_chat_id, contact=contact_name)
                    return True, f"Delivered to Telegram chat {clean_chat_id}"
                else:
                    err = f"Telegram API error {resp.status_code}: {resp.text}"
                    logger.warning("telegram_test_ping_failed", error=err)
                    return False, err
        except Exception as e:
            logger.error("telegram_test_ping_exception", error=str(e))
            return False, str(e)

    async def send_emergency_message(self, chat_id: str, message: str, lat: float | None = None, lng: float | None = None) -> tuple[bool, str]:
        if not self._settings.has_telegram:
            return False, "Telegram Bot not configured (TELEGRAM_BOT_TOKEN missing)"

        try:
            bot_token = self._settings.telegram_bot_token.strip()
            url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
            
            # Formatting the message
            location_text = f"\nLocation: https://maps.google.com/?q={lat},{lng}" if lat and lng else ""
            full_message = f"🚨 *GUARDIAN AI EMERGENCY ALERT* 🚨\n\n{message}{location_text}"

            payload = {
                "chat_id": chat_id,
                "text": full_message,
                "parse_mode": "Markdown",
                "disable_web_page_preview": False
            }

            async with httpx.AsyncClient(timeout=15.0) as client:
                resp = await client.post(url, json=payload)
                if resp.status_code == 200:
                    return True, f"Sent to Telegram chat {chat_id}"
                else:
                    err = f"Telegram API error {resp.status_code}: {resp.text}"
                    logger.warning("telegram_send_failed", error=err)
                    return False, err
        except Exception as e:
            logger.error("telegram_send_exception", error=str(e))
            return False, str(e)
