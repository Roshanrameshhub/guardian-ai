import json
import os
import firebase_admin
from firebase_admin import credentials, messaging

from app.core.config import get_settings
from app.core.logging import get_logger

logger = get_logger("fcm_provider")


class FcmProvider:
    _initialized = False

    @classmethod
    def _initialize(cls):
        if cls._initialized or bool(firebase_admin._apps):
            cls._initialized = True
            return

        settings = get_settings()
        if not settings.has_push:
            return

        try:
            key_val = settings.firebase_service_account_key.strip()
            if key_val:
                # 1. Direct JSON string in environment variable
                if key_val.startswith("{"):
                    cred_dict = json.loads(key_val)
                    cred = credentials.Certificate(cred_dict)
                # 2. File path (if file exists on disk)
                elif os.path.isfile(key_val):
                    cred = credentials.Certificate(key_val)
                # 3. Base64-encoded JSON string in environment variable
                else:
                    import base64
                    try:
                        decoded = base64.b64decode(key_val).decode("utf-8")
                        if decoded.startswith("{"):
                            cred_dict = json.loads(decoded)
                            cred = credentials.Certificate(cred_dict)
                        else:
                            raise ValueError("Not JSON")
                    except Exception:
                        logger.warning("fcm_credential_file_not_found", path=key_val)
                        return

                firebase_admin.initialize_app(cred)
                cls._initialized = True
                logger.info("fcm_initialized_with_service_account_key")
            elif os.environ.get("GOOGLE_APPLICATION_CREDENTIALS"):
                # 4. Fallback: Google Application Default Credentials (ADC)
                firebase_admin.initialize_app()
                cls._initialized = True
                logger.info("fcm_initialized_with_adc")
        except Exception as e:
            logger.error("fcm_init_error", error=str(e))
            cls._initialized = False


    async def send_emergency_push(
        self,
        token: str,
        title: str,
        body: str,
        data: dict | None = None
    ) -> tuple[bool, str]:
        """
        Sends a push notification via Firebase Admin SDK.
        Returns (success, reason_or_message_id)
        """
        self._initialize()
        
        if not self._initialized:
            return False, "FCM not properly initialized (missing service account credentials)"
            
        try:
            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=data or {},
                token=token,
            )
            # send() is synchronous in firebase_admin, but we are running in an async context.
            # For a prototype it is acceptable, or we can use asyncio.to_thread.
            import asyncio
            response = await asyncio.to_thread(messaging.send, message)
            return True, response
        except Exception as e:
            logger.warning("fcm_send_failed", error=str(e))
            return False, str(e)
