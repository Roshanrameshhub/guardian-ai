from __future__ import annotations

import os
from functools import lru_cache
from typing import List

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # ── Application ───────────────────────────────────────────────────────────
    app_env: str = "development"
    app_secret_key: str = "change-me-in-production"
    app_debug: bool = True
    app_version: str = "1.0.0"
    app_name: str = "Guardian AI API"

    # ── Database ──────────────────────────────────────────────────────────────
    database_url: str = "postgresql+asyncpg://guardian:guardian_pass@localhost:5432/guardian_ai"

    # ── Redis ─────────────────────────────────────────────────────────────────
    redis_url: str = "redis://localhost:6379/0"

    # ── JWT ───────────────────────────────────────────────────────────────────
    jwt_secret: str = "change-me-jwt-secret"
    jwt_refresh_secret: str = "change-me-refresh-secret"
    jwt_algorithm: str = "HS256"
    jwt_access_expire_minutes: int = 60
    jwt_refresh_expire_days: int = 30

    # ── CORS ──────────────────────────────────────────────────────────────────
    cors_origins: str = "http://localhost:3000,http://localhost:8080"
    cors_origin_regex: str = r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"

    @property
    def cors_origins_list(self) -> List[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def effective_cors_origin_regex(self) -> str | None:
        """Allow dynamic localhost/127.0.0.1 ports in development/test only."""
        if not self.is_production:
            return self.cors_origin_regex
        return None

    # ── Google OAuth ──────────────────────────────────────────────────────────
    google_client_id: str = "638591615239-q9ggn1oo47015msgb982egplt3mhigcf.apps.googleusercontent.com"
    google_client_secret: str = ""
    google_redirect_uri: str = "http://localhost:8000/api/v1/auth/google/callback"

    # ── External APIs ─────────────────────────────────────────────────────────
    maps_api_key: str = ""
    weather_api_key: str = ""
    gemini_api_key: str = ""
    gemini_model: str = "gemini-flash-latest"

    ai_max_context_tokens: int = 2000
    safety_data_api_key: str = ""
    safety_data_base_url: str = ""

    # ── Voice Distress Analysis ───────────────────────────────────────────────
    voice_analysis_enabled: bool = True
    voice_max_clip_seconds: int = 8
    voice_urgency_threshold: float = 0.75

    # ── Journey Monitoring & Stationary Detection ─────────────────────────────
    journey_stationary_warning_minutes: int = 10
    journey_stationary_critical_minutes: int = 20

    # ── Push / SMS / Email ────────────────────────────────────────────────────
    firebase_service_account_key: str = ""
    twilio_account_sid: str = ""
    twilio_auth_token: str = ""
    twilio_from_number: str = ""
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_from: str = "noreply@guardian.ai"

    # ── Weather Cache ─────────────────────────────────────────────────────────
    weather_cache_ttl_seconds: int = 600

    # ── Guardian Safety Engine ───────────────────────────────────────────────
    safety_zone_radius_meters: float = 600.0
    route_safety_weight: float = 0.60
    traffic_weight: float = 0.20
    time_weight: float = 0.15
    distance_weight: float = 0.05

    # ── Guardian Watchdog ─────────────────────────────────────────────────────
    guardian_heartbeat_timeout_seconds: int = 120
    guardian_grace_period_seconds: int = 60

    # ── Rate Limiting ─────────────────────────────────────────────────────────
    rate_limit_auth_per_minute: int = 10
    rate_limit_sos_per_minute: int = 5
    rate_limit_ai_per_minute: int = 20
    rate_limit_location_per_minute: int = 120

    # ── Derived helpers ───────────────────────────────────────────────────────
    @property
    def is_production(self) -> bool:
        return self.app_env == "production"

    @property
    def has_maps(self) -> bool:
        return bool(self.maps_api_key)

    @property
    def has_weather(self) -> bool:
        return bool(self.weather_api_key)

    @property
    def has_ai(self) -> bool:
        return bool(self.gemini_api_key)

    @property
    def has_google_auth(self) -> bool:
        return bool(self.google_client_id)

    @property
    def has_push(self) -> bool:
        return bool(
            self.firebase_service_account_key
            or os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
        )

    @property
    def has_sms(self) -> bool:
        return bool(self.twilio_account_sid and self.twilio_auth_token)


@lru_cache
def get_settings() -> Settings:
    return Settings()

