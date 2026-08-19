from __future__ import annotations

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_google_auth_mock_login(client: AsyncClient):
    """Verify Google sign-in endpoint auto-provisions a Guardian user and issues JWT tokens."""
    payload = {
        "id_token": "mock_google_token_newuser@guardian.ai",
        "platform": "android",
    }
    resp = await client.post("/api/v1/auth/google", json=payload)
    assert resp.status_code == 200
    data = resp.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["token_type"] == "bearer"
    assert "user_id" in data


@pytest.mark.asyncio
async def test_google_auth_returning_user(client: AsyncClient):
    """Verify returning Google user receives renewed JWT tokens."""
    payload = {
        "id_token": "mock_google_token_returning@guardian.ai",
        "platform": "android",
    }
    # First login (creates user)
    resp1 = await client.post("/api/v1/auth/google", json=payload)
    assert resp1.status_code == 200
    user_id_1 = resp1.json()["user_id"]

    # Second login (authenticates existing user)
    resp2 = await client.post("/api/v1/auth/google", json=payload)
    assert resp2.status_code == 200
    user_id_2 = resp2.json()["user_id"]
    assert user_id_1 == user_id_2


@pytest.mark.asyncio
async def test_google_auth_invalid_token(client: AsyncClient):
    """Verify invalid token format or rejected token throws 401."""
    payload = {
        "id_token": "invalid_unauthenticated_token_xyz_12345",
        "platform": "android",
    }
    resp = await client.post("/api/v1/auth/google", json=payload)
    assert resp.status_code == 401
