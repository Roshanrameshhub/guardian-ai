import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_health_check(client: AsyncClient):
    response = await client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


@pytest.mark.asyncio
async def test_ready_check(client: AsyncClient):
    response = await client.get("/ready")
    assert response.status_code == 200
    assert "status" in response.json()


@pytest.mark.asyncio
async def test_auth_and_profile_flow(client: AsyncClient):
    # Register
    email = "newuser@guardian.ai"
    reg = await client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "New Safety User",
            "email": email,
            "phone": "+1 555 987 6543",
            "password": "SecurePassword123!",
        },
    )
    assert reg.status_code == 201
    auth_data = reg.json()
    assert "access_token" in auth_data
    assert "refresh_token" in auth_data

    headers = {"Authorization": f"Bearer {auth_data['access_token']}"}

    # Fetch Profile
    prof = await client.get("/api/v1/profile", headers=headers)
    assert prof.status_code == 200
    assert prof.json()["name"] == "New Safety User"
    assert prof.json()["email"] == email

    # Fetch Dashboard
    dash = await client.get("/api/v1/dashboard", headers=headers)
    assert dash.status_code == 200
    assert "safety_score" in dash.json()
    assert dash.json()["guardian_mode_active"] is False


@pytest.mark.asyncio
async def test_guardian_lifecycle(client: AsyncClient, auth_headers: dict):
    # Start Guardian
    start_res = await client.post("/api/v1/guardian/start", headers=auth_headers)
    assert start_res.status_code == 201
    start_data = start_res.json()
    assert start_data["is_active"] is True
    assert start_data["session_id"] is not None

    session_id = start_data["session_id"]

    # Send Heartbeat
    hb_res = await client.post(
        f"/api/v1/guardian/{session_id}/heartbeat",
        headers=auth_headers,
        json={"lat": 13.0827, "lng": 80.2707, "battery_percent": 95},
    )
    assert hb_res.status_code == 200

    # Stop Guardian
    stop_res = await client.post("/api/v1/guardian/stop", headers=auth_headers)
    assert stop_res.status_code == 200
    assert stop_res.json()["is_active"] is False


@pytest.mark.asyncio
async def test_emergency_sos(client: AsyncClient, auth_headers: dict):
    sos_res = await client.post(
        "/api/v1/emergency/sos",
        headers=auth_headers,
        json={"lat": 13.0827, "lng": 80.2707, "trigger_source": "manual"},
    )
    assert sos_res.status_code == 201
    assert sos_res.json()["success"] is True
    assert "event_id" in sos_res.json()


@pytest.mark.asyncio
async def test_device_token_registration(client: AsyncClient, auth_headers: dict):
    token_res = await client.post(
        "/api/v1/notifications/device-token",
        headers=auth_headers,
        json={"token": "fcm_test_token_xyz", "platform": "android", "app_version": "1.2.0"},
    )
    assert token_res.status_code == 200
    assert token_res.json()["success"] is True


@pytest.mark.asyncio
async def test_weather_endpoint(client: AsyncClient, auth_headers: dict):
    weather_res = await client.get("/api/v1/weather?lat=13.0827&lng=80.2707", headers=auth_headers)
    assert weather_res.status_code == 200
    data = weather_res.json()
    assert "temperature_c" in data
    assert "condition" in data


@pytest.mark.asyncio
async def test_trusted_contacts_lifecycle(client: AsyncClient, auth_headers: dict):
    # 1. Create Contact
    create_res = await client.post(
        "/api/v1/contacts",
        headers=auth_headers,
        json={
            "name": "Sarah Connor",
            "phone": "+1 555 0199",
            "relationship_label": "Mother",
            "emergency_notify_enabled": True,
            "location_share_enabled": False,
            "priority": 1,
        },
    )
    assert create_res.status_code == 201
    contact = create_res.json()
    contact_id = contact["id"]
    assert contact["name"] == "Sarah Connor"

    # 2. List Contacts
    list_res = await client.get("/api/v1/contacts", headers=auth_headers)
    assert list_res.status_code == 200
    contacts = list_res.json()
    assert any(c["id"] == contact_id for c in contacts)

    # 3. Update Contact
    update_res = await client.patch(
        f"/api/v1/contacts/{contact_id}",
        headers=auth_headers,
        json={"relationship_label": "Guardian", "priority": 2},
    )
    assert update_res.status_code == 200
    assert update_res.json()["relationship_label"] == "Guardian"

    # 4. Delete Contact
    delete_res = await client.delete(f"/api/v1/contacts/{contact_id}", headers=auth_headers)
    assert delete_res.status_code == 200
    assert delete_res.json()["success"] is True

