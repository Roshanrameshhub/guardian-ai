import httpx
import structlog

from app.core.config import get_settings

logger = structlog.get_logger("telegram_provider")


class TelegramProvider:
    def __init__(self):
        self._settings = get_settings()

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
