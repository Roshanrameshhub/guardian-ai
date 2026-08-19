import pytest
from app.core.config import Settings
from app.services.fcm_provider import FcmProvider


def test_fcm_settings_properties():
    settings = Settings(firebase_service_account_key="")
    assert settings.firebase_service_account_key == ""
    assert settings.has_push is False

    settings_with_key = Settings(firebase_service_account_key="some/path/to/key.json")
    assert settings_with_key.firebase_service_account_key == "some/path/to/key.json"
    assert settings_with_key.has_push is True


@pytest.mark.asyncio
async def test_fcm_provider_graceful_fallback_when_unconfigured():
    provider = FcmProvider()
    # Reset initialization flag for test
    provider._initialized = False

    success, message = await provider.send_emergency_push(
        token="test_token",
        title="Test Title",
        body="Test Body",
    )
    assert success is False
    assert "not properly initialized" in message or "missing" in message.lower()
