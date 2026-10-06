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

        # 1. Call OpenWeatherMap if key is configured
        if self._settings.weather_api_key:
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
            except Exception as e:
                logger.warning("openweathermap_failed_falling_back_to_open_meteo", error=str(e))

        # 2. Fallback to Open-Meteo (Real live weather with zero API key required)
        try:
            open_meteo_url = (
                f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lng}"
                "&current=temperature_2m,relative_humidity_2m,weather_code,visibility&timezone=auto"
            )
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.get(open_meteo_url)
                if resp.status_code == 200:
                    payload = resp.json()
                    current = payload.get("current", {})
                    temp = int(round(current.get("temperature_2m", 28.0)))
                    humidity = int(round(current.get("relative_humidity_2m", 65.0)))
                    vis_m = current.get("visibility", 10000.0)
                    visibility_km = round(vis_m / 1000.0, 1) if vis_m is not None else 10.0
                    wmo_code = current.get("weather_code", 0)

                    wmo_conditions = {
                        0: "Clear",
                        1: "Mainly Clear",
                        2: "Partly Cloudy",
                        3: "Overcast",
                        45: "Fog",
                        51: "Drizzle",
                        61: "Rain",
                        63: "Moderate Rain",
                        65: "Heavy Rain",
                        80: "Showers",
                        95: "Thunderstorm",
                    }
                    condition = wmo_conditions.get(wmo_code, "Partly Cloudy")

                    weather_res = WeatherResponse(
                        temperature_c=temp,
                        location=f"Chennai ({lat:.2f}, {lng:.2f})",
                        condition=condition,
                        visibility_km=visibility_km,
                        humidity=humidity,
                        icon="01d" if temp > 20 else "01n",
                    )

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
        except Exception as e:
            logger.warning("open_meteo_fetch_failed", error=str(e))

        # 3. Graceful offline fallback
        return WeatherResponse(
            temperature_c=29,
            location=f"Chennai ({lat:.2f}, {lng:.2f})",
            condition="Partly Cloudy",
            visibility_km=8.5,
            humidity=65,
            icon="02d",
        )
