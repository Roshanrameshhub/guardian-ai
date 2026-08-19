from __future__ import annotations

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_get_safety_zones(client: AsyncClient):
    res = await client.get("/api/v1/guardian/safety-zones")
    assert res.status_code == 200
    zones = res.json()
    assert len(zones) == 56

    # Verify first zone (Adyar) and Broken Bridge zone
    adyar = next((z for z in zones if z["id"] == "CHN001"), None)
    assert adyar is not None
    assert adyar["place"] == "Adyar"
    assert adyar["day_risk_score"] == 18
    assert adyar["night_risk_score"] == 10
    assert adyar["demo_safety_score"] == 88

    broken_bridge = next((z for z in zones if z["id"] == "CHN043"), None)
    assert broken_bridge is not None
    assert broken_bridge["place"] == "Broken Bridge"
    assert broken_bridge["day_risk_score"] == 72
    assert broken_bridge["night_risk_score"] == 90
    assert "disclaimer" in broken_bridge


@pytest.mark.asyncio
async def test_get_police_stations(client: AsyncClient):
    # Query near Adyar (13.0067, 80.2567)
    res = await client.get("/api/v1/guardian/police-stations?lat=13.0067&lng=80.2567&limit=5")
    assert res.status_code == 200
    stations = res.json()
    assert len(stations) > 0

    # Nearest station should be J2 Adyar or J5 Sastri Nagar
    first = stations[0]
    assert "station_name" in first
    assert "contact_number" in first
    assert "distance_display" in first
    assert first["distance_meters"] >= 0


@pytest.mark.asyncio
async def test_get_nearby_help(client: AsyncClient):
    res = await client.get("/api/v1/guardian/nearby-help?lat=13.0067&lng=80.2567")
    assert res.status_code == 200
    data = res.json()
    assert "nearest_summary" in data
    assert "police_stations" in data
    assert "hospitals" in data
    assert "stations" in data
    assert "active_places" in data
    assert "disclaimer" in data


@pytest.mark.asyncio
async def test_guardian_route_day_vs_night(client: AsyncClient):
    # Origin: Adyar (13.0067, 80.2567), Destination: Marina Beach (13.0556, 80.2821)
    req_payload_day = {
        "origin": {"latitude": 13.0067, "longitude": 80.2567},
        "destination": {"latitude": 13.0556, "longitude": 80.2821, "name": "Marina Beach"},
        "travel_mode": "DRIVE",
        "departure_time": "2026-08-16T14:00:00+05:30",  # Day time: 2 PM
    }

    res_day = await client.post("/api/v1/guardian/route", json=req_payload_day)
    assert res_day.status_code == 200
    data_day = res_day.json()
    assert data_day["is_night"] is False
    assert data_day["evaluation_period"] == "Day"
    assert "recommended_route" in data_day
    assert "alternative_routes" in data_day
    assert len(data_day["alternative_routes"]) >= 2
    assert "disclaimer" in data_day

    # Night time: 11 PM
    req_payload_night = {
        "origin": {"latitude": 13.0067, "longitude": 80.2567},
        "destination": {"latitude": 13.0556, "longitude": 80.2821, "name": "Marina Beach"},
        "travel_mode": "DRIVE",
        "departure_time": "2026-08-16T23:00:00+05:30",  # Night time: 11 PM
    }

    res_night = await client.post("/api/v1/guardian/route", json=req_payload_night)
    assert res_night.status_code == 200
    data_night = res_night.json()
    assert data_night["is_night"] is True
    assert data_night["evaluation_period"] == "Night"


@pytest.mark.asyncio
async def test_guardian_route_safety_exposure(client: AsyncClient):
    # Route close to Broken Bridge vs safe main corridor
    req = {
        "origin": {"latitude": 13.0001, "longitude": 80.2667},  # Besant Nagar
        "destination": {"latitude": 13.0367, "longitude": 80.2678, "name": "Mylapore"},
        "travel_mode": "DRIVE",
    }
    res = await client.post("/api/v1/guardian/route", json=req)
    assert res.status_code == 200
    data = res.json()
    assert "safety_score" in data
    assert 0 <= data["safety_score"] <= 100
    assert "risk_level" in data
    assert "reason" in data
    assert len(data["recommended_route"]["points"]) > 0
