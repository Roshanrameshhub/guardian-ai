from __future__ import annotations

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_journey_stationary_check_traffic_delay(client: AsyncClient, auth_headers: dict):
    """Verify that heavy traffic congestion is classified as normal traffic delay, not an incident."""
    # 1. Start journey
    start_resp = await client.post(
        "/api/v1/journey/start",
        json={"origin": "Anna Nagar", "destination": "T Nagar"},
        headers=auth_headers,
    )
    assert start_resp.status_code == 201
    journey_id = start_resp.json()["id"]

    # 2. Check stationary with heavy traffic
    check_resp = await client.post(
        "/api/v1/journey/stationary-check",
        json={
            "journey_id": journey_id,
            "current_lat": 13.0827,
            "current_lng": 80.2707,
            "speed_kmh": 2.0,
            "stationary_minutes": 12,
            "traffic_congestion_level": "HEAVY",
        },
        headers=auth_headers,
    )
    assert check_resp.status_code == 200
    data = check_resp.json()
    assert data["is_stationary"] is True
    assert data["is_traffic_delay"] is True
    assert data["alert_level"] == "NONE"
    assert data["requires_prompt"] is False


@pytest.mark.asyncio
async def test_journey_stationary_check_unexpected_stop(client: AsyncClient, auth_headers: dict):
    """Verify that an unexpected stop with no traffic congestion triggers progressive alerts."""
    # 1. Start journey
    start_resp = await client.post(
        "/api/v1/journey/start",
        json={"origin": "Mylapore", "destination": "Velachery"},
        headers=auth_headers,
    )
    journey_id = start_resp.json()["id"]

    # 2. 10-minute warning check-in
    warn_resp = await client.post(
        "/api/v1/journey/stationary-check",
        json={
            "journey_id": journey_id,
            "current_lat": 13.0334,
            "current_lng": 80.2678,
            "speed_kmh": 0.0,
            "stationary_minutes": 10,
            "traffic_congestion_level": "LOW",
        },
        headers=auth_headers,
    )
    assert warn_resp.status_code == 200
    warn_data = warn_resp.json()
    assert warn_data["is_stationary"] is True
    assert warn_data["is_traffic_delay"] is False
    assert warn_data["alert_level"] == "LEVEL_1_CHECKIN"
    assert warn_data["requires_prompt"] is True

    # 3. 20-minute critical assistance check-in
    crit_resp = await client.post(
        "/api/v1/journey/stationary-check",
        json={
            "journey_id": journey_id,
            "current_lat": 13.0334,
            "current_lng": 80.2678,
            "speed_kmh": 0.0,
            "stationary_minutes": 22,
            "traffic_congestion_level": "LOW",
        },
        headers=auth_headers,
    )
    assert crit_resp.status_code == 200
    crit_data = crit_resp.json()
    assert crit_data["alert_level"] == "LEVEL_3_ASSISTANCE"
    assert crit_data["requires_prompt"] is True


@pytest.mark.asyncio
async def test_journey_reroute_endpoint(client: AsyncClient, auth_headers: dict):
    """Verify safety-aware rerouting returns ranked route alternatives."""
    # 1. Start journey
    start_resp = await client.post(
        "/api/v1/journey/start",
        json={
            "origin": "Chennai Central",
            "destination": "Besant Nagar Beach",
            "origin_lat": 13.0827,
            "origin_lng": 80.2707,
            "dest_lat": 13.0001,
            "dest_lng": 80.2667,
        },
        headers=auth_headers,
    )
    journey_id = start_resp.json()["id"]

    # 2. Trigger reroute
    reroute_resp = await client.post(
        "/api/v1/journey/reroute",
        json={
            "journey_id": journey_id,
            "current_lat": 13.0500,
            "current_lng": 80.2500,
            "destination_lat": 13.0001,
            "destination_lng": 80.2667,
            "destination_name": "Besant Nagar Beach",
            "travel_mode": "DRIVE",
        },
        headers=auth_headers,
    )
    assert reroute_resp.status_code == 200
    data = reroute_resp.json()
    assert "recommended_route" in data
    assert "alternative_routes" in data
    assert len(data["alternative_routes"]) >= 1
    assert data["recommended_route"]["role"] == "Safer Route"
