import asyncio
import httpx
import structlog
from datetime import datetime, timezone
from sqlalchemy import select

from app.core.config import get_settings
from app.core.database import AsyncSessionLocal
from app.models.contact import TrustedContact

logger = structlog.get_logger("telegram_bot_poller")

async def telegram_polling_task() -> None:
    settings = get_settings()
    if not settings.has_telegram:
        logger.info("Telegram polling skipped (TELEGRAM_BOT_TOKEN missing)")
        return
        
    bot_token = settings.telegram_bot_token.strip()
    url = f"https://api.telegram.org/bot{bot_token}/getUpdates"
    
    offset = 0
    timeout = 30
    
    logger.info("Starting Telegram bot polling")
    
    async with httpx.AsyncClient(timeout=timeout + 5.0) as client:
        while True:
            try:
                params = {"offset": offset, "timeout": timeout}
                resp = await client.get(url, params=params)
                
                if resp.status_code == 200:
                    data = resp.json()
                    if not data.get("ok"):
                        logger.error("Telegram getUpdates returned not ok", data=data)
                        await asyncio.sleep(5)
                        continue
                        
                    updates = data.get("result", [])
                    for update in updates:
                        offset = update["update_id"] + 1
                        
                        message = update.get("message")
                        if not message:
                            continue
                            
                        text = message.get("text", "")
                        chat_id = str(message["chat"]["id"])
                        
                        if text.startswith("/start"):
                            parts = text.split()
                            if len(parts) == 2:
                                token = parts[1]
                                await _handle_link_token(chat_id, token, client, bot_token)
                            else:
                                await _send_message(client, bot_token, chat_id, "Welcome to Guardian AI Alert Bot! Ask the user to generate a linking link from the Guardian AI app.")
                                
            except asyncio.CancelledError:
                logger.info("Telegram polling stopped")
                break
            except httpx.ReadTimeout:
                continue
            except Exception as e:
                logger.error("Telegram polling error", error=str(e))
                await asyncio.sleep(5)


async def _handle_link_token(chat_id: str, token: str, client: httpx.AsyncClient, bot_token: str):
    try:
        async with AsyncSessionLocal() as db:
            now = datetime.now(tz=timezone.utc)
            contact = await db.scalar(
                select(TrustedContact).where(TrustedContact.telegram_link_token == token)
            )
            
            if contact:
                if contact.telegram_link_expires and contact.telegram_link_expires > now:
                    contact.telegram_chat_id = chat_id
                    contact.telegram_link_token = None # consume token
                    contact.telegram_link_expires = None
                    await db.commit()
                    
                    await _send_message(
                        client, bot_token, chat_id, 
                        f"✅ Successfully linked! You will now receive emergency alerts for {contact.name} from Guardian AI."
                    )
                else:
                    await _send_message(client, bot_token, chat_id, "❌ This link token has expired. Please generate a new one from the Guardian AI app.")
            else:
                await _send_message(client, bot_token, chat_id, "❌ Invalid link token. Please generate a new one from the Guardian AI app.")
    except Exception as e:
        logger.error("Error handling link token", error=str(e))
        await _send_message(client, bot_token, chat_id, "❌ An internal error occurred while linking.")


async def _send_message(client: httpx.AsyncClient, bot_token: str, chat_id: str, text: str):
    url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
    payload = {"chat_id": chat_id, "text": text}
    try:
        await client.post(url, json=payload)
    except Exception as e:
        logger.error("Telegram poller reply failed", error=str(e))
