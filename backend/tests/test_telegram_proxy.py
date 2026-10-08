import pytest
from httpx import AsyncClient, Response
from unittest.mock import patch, AsyncMock

from app.core.config import get_settings
from app.services.telegram_provider import TelegramProvider


@pytest.mark.asyncio
async def test_telegram_proxy_unconfigured(client: AsyncClient):
    """When TELEGRAM_BOT_TOKEN is not configured, endpoints return truthful failure."""
    with patch.object(get_settings(), "telegram_bot_token", ""):
        # Test alert proxy
        res_alert = await client.post(
            "/api/v1/notifications/telegram/alert",
            json={
                "chat_id": "12345678",
                "contact_name": "Test Contact",
                "lat": 12.9716,
                "lng": 77.5946,
                "reason": "Test Alert",
            },
        )
        assert res_alert.status_code == 200
        data = res_alert.json()
        assert data["success"] is False
        assert "not configured" in data["message"].lower()

        # Test ping proxy
        res_test = await client.post(
            "/api/v1/notifications/telegram/test",
            json={
                "chat_id": "12345678",
                "contact_name": "Test Contact",
            },
        )
        assert res_test.status_code == 200
        data_test = res_test.json()
        assert data_test["success"] is False
        assert "not configured" in data_test["message"].lower()


@pytest.mark.asyncio
async def test_telegram_proxy_endpoints_dispatch(client: AsyncClient):
    """Proxy endpoints invoke provider methods and return ApiMessageResponse."""
    with patch("app.services.telegram_provider.TelegramProvider.send_emergency_alert", new_callable=AsyncMock) as mock_alert, \
         patch("app.services.telegram_provider.TelegramProvider.send_test_ping", new_callable=AsyncMock) as mock_ping:
        mock_alert.return_value = (True, "Sent to Telegram chat 987654321")
        mock_ping.return_value = (True, "Delivered to Telegram chat 987654321")

        # 1. Alert proxy
        res_alert = await client.post(
            "/api/v1/notifications/telegram/alert",
            json={
                "chat_id": "987654321",
                "contact_name": "Alice",
                "lat": 13.0827,
                "lng": 80.2707,
                "reason": "SOS Distress",
                "battery_level": 85,
            },
        )
        assert res_alert.status_code == 200
        data_alert = res_alert.json()
        assert data_alert["success"] is True
        assert mock_alert.called

        # 2. Test ping proxy
        res_test = await client.post(
            "/api/v1/notifications/telegram/test",
            json={
                "chat_id": "987654321",
                "contact_name": "Alice",
            },
        )
        assert res_test.status_code == 200
        data_test = res_test.json()
        assert data_test["success"] is True
        assert mock_ping.called


@pytest.mark.asyncio
async def test_telegram_provider_methods():
    """Test TelegramProvider internal methods with configured token."""
    mock_token = "123456:ABC-DEF-MOCK"
    with patch.object(get_settings(), "telegram_bot_token", mock_token):
        provider = TelegramProvider()
        assert provider._settings.has_telegram is True

        mock_client = AsyncMock()
        mock_client.__aenter__.return_value = mock_client
        mock_client.post.return_value = Response(200, json={"ok": True})

        with patch("app.services.telegram_provider.httpx.AsyncClient", return_value=mock_client):
            # Test alert
            ok, msg = await provider.send_emergency_alert(
                chat_id="999",
                contact_name="Bob",
                lat=13.0,
                lng=80.0,
                reason="Danger",
                battery_level=50,
            )
            assert ok is True
            assert "999" in msg
            assert mock_client.post.called
            call_url = mock_client.post.call_args[0][0]
            assert f"/bot{mock_token}/sendMessage" in call_url

            # Test ping
            ok2, msg2 = await provider.send_test_ping(chat_id="999", contact_name="Bob")
            assert ok2 is True
            assert "999" in msg2
