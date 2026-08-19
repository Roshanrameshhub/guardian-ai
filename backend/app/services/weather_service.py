from __future__ import annotations

import json
from datetime import datetime, timezone
import httpx
import redis.asyncio as aioredis
import structlog

from app.core.config import get_settings
from app.schemas.weather import WeatherResponse

logger = structlog.get_logger()
settings = get_settings()


class WeatherService:
    def __init__(self) -> None:
        self._settings = settings
        self._redis_client: aioredis.Redis | None = None

    async def _get_redis(self) -> aioredis.Redis | None:
        if self._redis_client is None and self._settings.redis_url:
            try:
                self._redis_client = aioredis.from_url(
                    self._settings.redis_url,
                    decode_responses=True,
                    socket_connect_timeout=2,
                )
            except Exception as e:
                logger.warning("redis_connection_failed", error=str(e))
                self._redis_client = None
        return self._redis_client

    async def get_weather(self, lat: float, lng: float) -> WeatherResponse:
        """
        Fetch real live weather for coordinates.
        1. Check Redis cache (ttl: settings.weather_cache_ttl_seconds).
        2. Query OpenWeatherMap API if WEATHER_API_KEY is configured.
        3. Cache and return response.
        4. If WEATHER_API_KEY is missing or upstream fails, return truthful unavailable status.
        """
        cache_key = f"weather:{round(lat, 2)}:{round(lng, 2)}"
        r = await self._get_redis()

        if r:
            try:
                cached = await r.get(cache_key)
                if cached:
                    data = json.loads(cached)
                    return WeatherResponse(**data)
            except Exception as e:
                logger.warning("weather_cache_read_error", error=str(e))

        if not self._settings.weather_api_key:
            return WeatherResponse(
                temperature_c=0,
                location=f"GPS ({lat:.2f}, {lng:.2f})",
                condition="Weather API key not configured",
                visibility_km=0.0,
                humidity=0,
                icon=None,
            )

        # Call OpenWeatherMap
        url = "https://api.openweathermap.org/data/2.5/weather"
        params = {
            "lat": lat,
            "lon": lng,
            "appid": self._settings.weather_api_key,
            "units": "metric",
        }

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.get(url, params=params)
                if resp.status_code == 200:
                    payload = resp.json()
                    main = payload.get("main", {})
                    weather_list = payload.get("weather", [{}])
                    primary = weather_list[0] if weather_list else {}

                    temp = int(round(main.get("temp", 0)))
                    condition = primary.get("main", "Clear")
                    humidity = main.get("humidity", 0)
                    visibility_km = round(payload.get("visibility", 10000) / 1000.0, 1)
                    location_name = payload.get("name") or f"{lat:.2f}, {lng:.2f}"
                    icon = primary.get("icon")

                    weather_res = WeatherResponse(
                        temperature_c=temp,
                        location=location_name,
                        condition=condition,
                        visibility_km=visibility_km,
                        humidity=humidity,
                        icon=icon,
                    )

                    # Save to Redis
                    if r:
                        try:
                            await r.setex(
                                cache_key,
                                self._settings.weather_cache_ttl_seconds,
                                json.dumps(weather_res.model_dump()),
                            )
                        except Exception as e:
                            logger.warning("weather_cache_write_error", error=str(e))

                    return weather_res
                else:
                    logger.error("openweathermap_error", status=resp.status_code, body=resp.text)
                    return WeatherResponse(
                        temperature_c=0,
                        location=f"{lat:.2f}, {lng:.2f}",
                        condition="Weather unavailable",
                        visibility_km=0.0,
                        humidity=0,
                    )
        except Exception as e:
            logger.error("weather_fetch_failed", error=str(e))
            return WeatherResponse(
                temperature_c=0,
                location=f"{lat:.2f}, {lng:.2f}",
                condition="Weather service offline",
                visibility_km=0.0,
                humidity=0,
            )
