"""
Tests for MapsService and /api/v1/map/route endpoint.
Verifies real Google Maps handling, input validation, and truthful error propagation.
"""
import pytest
from unittest.mock import AsyncMock, patch, MagicMock
from httpx import AsyncClient
from app.services.maps_service import MapsService
from app.core.exceptions import (
    BadRequestError,
    ServiceUnavailableError,
    NotFoundError,
)


@pytest.mark.asyncio
async def test_get_route_missing_destination(client: AsyncClient, monkeypatch):
    """Calling /api/v1/map/route without destination must return 400 Bad Request."""
    from app.core.config import get_settings
    monkeypatch.setattr(get_settings(), "maps_api_key", "test_mock_api_key")
    res = await client.get("/api/v1/map/route?origin_lat=12.9563328&origin_lng=80.1828086")
    assert res.status_code == 400
    data = res.json()
    assert data["success"] is False
    assert data["error"] == "BAD_REQUEST"
    assert "Destination is required" in data["message"]


@pytest.mark.asyncio
async def test_get_route_invalid_origin_coordinates(client: AsyncClient, monkeypatch):
    """Invalid latitude or longitude must return 400 Bad Request."""
    from app.core.config import get_settings
    monkeypatch.setattr(get_settings(), "maps_api_key", "test_mock_api_key")
    res = await client.get("/api/v1/map/route?origin_lat=999.0&origin_lng=80.0&destination=Mylapore")
    assert res.status_code == 400
    data = res.json()
    assert data["success"] is False
    assert "Invalid origin coordinates" in data["message"]


@pytest.mark.asyncio
async def test_get_route_missing_api_key(monkeypatch):
    """When MAPS_API_KEY is empty, MapsService must raise ServiceUnavailableError."""
    service = MapsService()
    monkeypatch.setattr(service._settings, "maps_api_key", "")

    with pytest.raises(ServiceUnavailableError) as exc_info:
        await service.get_route(
            origin_lat=13.0827,
            origin_lng=80.2707,
            destination="Mylapore",
        )
    assert "Maps provider not configured" in str(exc_info.value)


@pytest.mark.asyncio
async def test_get_route_google_not_found(monkeypatch):
    """When Google Directions returns NOT_FOUND/ZERO_RESULTS, raise NotFoundError."""
    service = MapsService()
    monkeypatch.setattr(service._settings, "maps_api_key", "test_mock_api_key")
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {
        "status": "ZERO_RESULTS",
        "routes": [],
        "error_message": "No route could be found between the points.",
    }

    with patch.object(service, "_call_google_routes_v2", new_callable=AsyncMock) as mock_v2:
        mock_v2.return_value = None
        with patch("httpx.AsyncClient.get", new_callable=AsyncMock) as mock_get:
            mock_get.return_value = mock_resp
            with pytest.raises(NotFoundError) as exc_info:
                await service.get_route(
                    origin_lat=13.0827,
                    origin_lng=80.2707,
                    destination="Nonexistent Place xyz123",
                )
            assert "No route found" in str(exc_info.value)


@pytest.mark.asyncio
async def test_get_route_google_request_denied(monkeypatch):
    """When Google Directions returns REQUEST_DENIED, raise ServiceUnavailableError."""
    service = MapsService()
    monkeypatch.setattr(service._settings, "maps_api_key", "test_mock_api_key")
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {
        "status": "REQUEST_DENIED",
        "routes": [],
        "error_message": "The provided API key is invalid.",
    }

    with patch.object(service, "_call_google_routes_v2", new_callable=AsyncMock) as mock_v2:
        mock_v2.return_value = None
        with patch("httpx.AsyncClient.get", new_callable=AsyncMock) as mock_get:
            mock_get.return_value = mock_resp
            with pytest.raises(ServiceUnavailableError) as exc_info:
                await service.get_route(
                    origin_lat=13.0827,
                    origin_lng=80.2707,
                    destination="Mylapore",
                )
            assert "Google Maps API rejected request" in str(exc_info.value)


@pytest.mark.asyncio
async def test_get_route_network_timeout(monkeypatch):
    """When HTTP request times out, raise ServiceUnavailableError."""
    import httpx
    service = MapsService()
    monkeypatch.setattr(service._settings, "maps_api_key", "test_mock_api_key")

    with patch.object(service, "_call_google_routes_v2", new_callable=AsyncMock) as mock_v2:
        mock_v2.return_value = None
        with patch("httpx.AsyncClient.get", side_effect=httpx.TimeoutException("Connection timed out")):
            with pytest.raises(ServiceUnavailableError) as exc_info:
                await service.get_route(
                    origin_lat=13.0827,
                    origin_lng=80.2707,
                    destination="Mylapore",
                )
            assert "timed out" in str(exc_info.value)


@pytest.mark.asyncio
async def test_get_route_successful(monkeypatch):
    """Successful route returns MapRouteResponse with polyline, distance, and duration."""
    service = MapsService()
    monkeypatch.setattr(service._settings, "maps_api_key", "test_mock_api_key")
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {
        "status": "OK",
        "routes": [
            {
                "summary": "Via Gandhi Mandapam Rd",
                "overview_polyline": {"points": "_p~iF~ps|U_ulLnnqC_mqNvxq`@"},
                "legs": [
                    {
                        "distance": {"value": 3400, "text": "3.4 km"},
                        "duration": {"value": 2400, "text": "40 mins"},
                        "end_address": "Mylapore, Chennai, Tamil Nadu",
                        "end_location": {"lat": 13.0367, "lng": 80.2678},
                        "start_location": {"lat": 13.0012, "lng": 80.2565},
                    }
                ],
            }
        ],
    }

    with patch.object(service, "_call_google_routes_v2", new_callable=AsyncMock) as mock_v2:
        mock_v2.return_value = None
        with patch("httpx.AsyncClient.get", new_callable=AsyncMock) as mock_get:
            mock_get.return_value = mock_resp
            route = await service.get_route(
                origin_lat=13.0012,
                origin_lng=80.2565,
                destination="Mylapore",
            )
            assert route.to == "Mylapore"
            assert route.distance_km == 3.4
            assert route.eta_minutes == 40
            assert route.via == "Via Gandhi Mandapam Rd"
            assert len(route.route_points) > 0
            assert route.dest_lat == 13.0367
            assert route.dest_lng == 80.2678
