"""
FCM Push Notification Verification Script
Uses the configured Firebase Service Account in backend/secrets/
Usage: python verify_fcm.py [optional_device_token]
"""
import sys
import asyncio

try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

from app.services.fcm_provider import FcmProvider


async def main():
    provider = FcmProvider()
    provider._initialize()

    if not provider._initialized:
        print("[FAIL] \u274c FCM Provider failed to initialize. Check backend/secrets/guardian-ai-firebase-adminsdk.json")
        sys.exit(1)

    print("[PASS] \u2705 Firebase Admin SDK successfully initialized with service account!")

    if len(sys.argv) > 1:
        test_token = sys.argv[1]
        print(f"[FCM] Sending test push notification to token: {test_token[:15]}...")
        success, res = await provider.send_emergency_push(
            token=test_token,
            title="Guardian AI Test Alert",
            body="FCM push notification pipeline verified and operational.",
            data={"type": "test_alert", "event_id": "test_001"}
        )
        if success:
            print(f"[PASS] \u2705 Push notification delivered! Message ID: {res}")
        else:
            print(f"[FAIL] \u274c Push delivery failed: {res}")
    else:
        print("[INFO] Service Account authenticated with FCM HTTP v1. To send a live message, provide a device token: python verify_fcm.py <token>")

if __name__ == "__main__":
    asyncio.run(main())
