"""
Twilio Controlled Verification Test Script
Usage: python verify_twilio.py +91XXXXXXXXXX
"""
import sys
import asyncio

try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

from app.services.sms_provider import TwilioSmsProvider


async def main():
    if len(sys.argv) < 2:
        print("Usage: python verify_twilio.py <phone_number_with_country_code>")
        print("Example: python verify_twilio.py +918148897839")
        sys.exit(1)

    to_number = sys.argv[1]
    if not to_number.startswith("+"):
        # Auto-prefix +91 if 10-digit Indian mobile number
        if len(to_number) == 10:
            to_number = f"+91{to_number}"
        else:
            to_number = f"+{to_number}"

    print(f"[TWILIO] Dispatching controlled test SMS to {to_number}...")
    provider = TwilioSmsProvider()
    success, result = await provider.send_emergency_sms(
        to_number=to_number,
        lat=13.0827,
        lng=80.2707,
        message="Guardian AI test alert: Systems verified and operational.",
        event_id="test_verify_001"
    )

    if success:
        print(f"\n[PASS] \u2705 SMS successfully sent via Twilio! Message SID: {result}")
    else:
        print(f"\n[FAIL] \u274c SMS failed to send: {result}")

if __name__ == "__main__":
    asyncio.run(main())
