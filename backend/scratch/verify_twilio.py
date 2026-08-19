"""
Twilio SMS Controlled Verification Script
Usage: python scratch/verify_twilio.py +91XXXXXXXXXX
"""
import asyncio
import os
import re
import sys

# Ensure backend root directory is in sys.path
backend_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if backend_root not in sys.path:
    sys.path.insert(0, backend_root)

# Ensure UTF-8 output on Windows terminal
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

from app.core.config import get_settings
from app.services.sms_provider import TwilioSmsProvider



def validate_e164(phone: str) -> tuple[bool, str]:
    """Validate E.164 phone number format (+[country code][subscriber number])."""
    pattern = r"^\+[1-9]\d{6,14}$"
    cleaned = phone.strip()
    if not cleaned.startswith("+"):
        if len(cleaned) == 10 and cleaned.isdigit():
            cleaned = f"+91{cleaned}"
        else:
            return False, f"Invalid format '{phone}'. Must start with '+' followed by country code (e.g. +91XXXXXXXXXX)."
    
    if not re.match(pattern, cleaned):
        return False, f"Invalid E.164 format '{cleaned}'. Must be + followed by 7 to 15 digits."
    
    return True, cleaned


async def main():
    settings = get_settings()

    print("==================================================")
    print("      GUARDIAN AI — TWILIO SMS VERIFICATION       ")
    print("==================================================")

    # 1. Check loaded configuration (without exposing secret values)
    sid_present = bool(settings.twilio_account_sid)
    token_present = bool(settings.twilio_auth_token)
    from_present = bool(settings.twilio_from_number)

    print(f"Twilio Account SID : {'[LOADED]' if sid_present else '[MISSING]'}")
    print(f"Twilio Auth Token  : {'[LOADED]' if token_present else '[MISSING]'}")
    print(f"Twilio From Number : {settings.twilio_from_number if from_present else '[MISSING]'}")
    print(f"Provider Ready     : {'YES' if settings.has_sms else 'NO'}")
    print("--------------------------------------------------")

    if not settings.has_sms:
        print("[ERROR] Twilio credentials are incomplete in backend/.env.")
        print("Ensure TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, and TWILIO_FROM_NUMBER are populated.")
        sys.exit(1)

    # 2. Check destination argument
    if len(sys.argv) < 2:
        print("Usage: python scratch/verify_twilio.py <destination_phone_number>")
        print("Example: python scratch/verify_twilio.py +918148897839")
        sys.exit(1)

    raw_input = sys.argv[1]
    is_valid, dest_number = validate_e164(raw_input)
    if not is_valid:
        print(f"[ERROR] {dest_number}")
        sys.exit(1)

    print(f"Dispatching controlled test SMS to: {dest_number}")
    print("Sending request to Twilio REST API...")

    # 3. Execute test through TwilioSmsProvider
    provider = TwilioSmsProvider()
    success, result = await provider.send_emergency_sms(
        to_number=dest_number,
        lat=13.0827,
        lng=80.2707,
        message="Guardian AI test alert: Twilio SMS pipeline verified and operational.",
        event_id="test_verify_prelaunch"
    )

    print("--------------------------------------------------")
    if success:
        print("[RESULT] SUCCESS")
        print(f"Message SID : {result}")
        print("SMS was accepted by Twilio for delivery.")
    else:
        print("[RESULT] FAILED")
        print(f"Reason      : {result}")

    print("==================================================")


if __name__ == "__main__":
    asyncio.run(main())
