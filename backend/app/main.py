from __future__ import annotations

import asyncio
import uuid
from contextlib import asynccontextmanager
from typing import Any

from fastapi import FastAPI, HTTPException, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.core.config import get_settings
from app.core.exceptions import (
    GuardianException,
    guardian_exception_handler,
    generic_exception_handler,
    http_exception_handler,
    validation_exception_handler,
)
from app.core.logging import configure_logging, get_logger

settings = get_settings()
configure_logging()
log = get_logger("guardian_ai")


# ─── Lifespan ─────────────────────────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application startup and shutdown lifecycle."""
    log.info(
        "Guardian AI API starting",
        env=settings.app_env,
        version=settings.app_version,
        has_maps=settings.has_maps,
        has_weather=settings.has_weather,
        has_ai=settings.has_ai,
        has_push=settings.has_push,
        has_sms=settings.has_sms,
    )

    # Seed Chennai Datasets (Police Stations & Safety Zones)
    try:
        from app.core.database import AsyncSessionLocal
        from app.services.seed_chennai_data import seed_chennai_datasets
        async with AsyncSessionLocal() as session:
            await seed_chennai_datasets(session)
    except Exception as e:
        log.warning("startup_seeding_skipped_or_failed", error=str(e))

    # Start background workers
    watchdog_task = asyncio.create_task(_run_watchdog())

    yield

    # Shutdown
    watchdog_task.cancel()
    try:
        await watchdog_task
    except asyncio.CancelledError:
        pass
    log.info("Guardian AI API shutdown complete")


async def _run_watchdog() -> None:
    try:
        from app.workers.guardian_watchdog import guardian_watchdog_task
        await guardian_watchdog_task()
    except asyncio.CancelledError:
        log.info("Guardian watchdog stopped")


# ─── App factory ──────────────────────────────────────────────────────────────

def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.app_name,
        version=settings.app_version,
        description=(
            "Guardian AI — Personal Safety Companion API. "
            "All endpoints use /api/v1/ prefix."
        ),
        docs_url="/docs",
        redoc_url="/redoc",
        lifespan=lifespan,
    )

    # ── CORS ──────────────────────────────────────────────────────────────────
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins_list,
        allow_origin_regex=settings.effective_cors_origin_regex,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # ── Request ID middleware ──────────────────────────────────────────────────
    @app.middleware("http")
    async def request_id_middleware(request: Request, call_next):
        request_id = str(uuid.uuid4())[:8]
        from app.core.dependencies import request_id_ctx
        token = request_id_ctx.set(request_id)
        import structlog
        structlog.contextvars.bind_contextvars(request_id=request_id)
        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        request_id_ctx.reset(token)
        structlog.contextvars.clear_contextvars()
        return response

    # ── Exception handlers ────────────────────────────────────────────────────
    app.add_exception_handler(GuardianException, guardian_exception_handler)
    app.add_exception_handler(HTTPException, http_exception_handler)
    app.add_exception_handler(RequestValidationError, validation_exception_handler)
    app.add_exception_handler(Exception, generic_exception_handler)

    # ── Health endpoints ───────────────────────────────────────────────────────
    @app.get("/health", tags=["Health"])
    @app.get("/api/v1/health", tags=["Health"])
    async def health() -> dict:
        return {"status": "ok", "app": settings.app_name, "version": settings.app_version}

    @app.get("/ready", tags=["Health"])
    @app.get("/api/v1/ready", tags=["Health"])
    async def ready() -> dict:
        """Checks actual dependency availability."""
        checks: dict[str, Any] = {}

        # Database
        try:
            from app.core.database import engine
            async with engine.connect() as conn:
                await conn.execute(__import__("sqlalchemy").text("SELECT 1"))
            checks["database"] = "ok"
        except Exception as e:
            checks["database"] = f"error: {type(e).__name__}"

        all_ok = all(v == "ok" for v in checks.values())
        return {
            "status": "ready" if all_ok else "degraded",
            "checks": checks,
            "providers": {
                "maps": "configured" if settings.has_maps else "mock",
                "weather": "configured" if settings.has_weather else "mock",
                "ai": "configured" if settings.has_ai else "mock",
                "push": "configured" if settings.has_push else "not_configured",
                "sms": "configured" if settings.has_sms else "not_configured",
            },
        }

    # ── API Routers (all prefixed with /api/v1) ────────────────────────────────
    from app.api.v1.auth import router as auth_router
    from app.api.v1.profile import profile_router, contacts_router
    from app.api.v1.journeys import router as journeys_router
    from app.api.v1.guardian import router as guardian_router
    from app.api.v1.dashboard import router as dashboard_router
    from app.api.v1.emergency import router as emergency_router
    from app.api.v1.activity import router as activity_router
    from app.api.v1.notifications import router as notifications_router
    from app.api.v1.achievements import router as achievements_router
    from app.api.v1.fake_tools import router as fake_tools_router
    from app.api.v1.safety import router as safety_router
    from app.api.v1.routes import router as routes_router
    from app.api.v1.weather import router as weather_router
    from app.api.v1.ai import router as ai_router
    from app.api.v1.intelligence import router as intelligence_router

    prefix = "/api/v1"
    app.include_router(auth_router, prefix=prefix)
    app.include_router(profile_router, prefix=prefix)
    app.include_router(contacts_router, prefix=prefix)
    app.include_router(journeys_router, prefix=prefix)
    app.include_router(guardian_router, prefix=prefix)
    
    # Direct alias for POST /api/guardian/route
    from fastapi import APIRouter
    from app.api.v1.guardian import calculate_guardian_safe_route
    direct_guardian_router = APIRouter(prefix="/api/guardian", tags=["Guardian (Direct)"])
    direct_guardian_router.add_api_route(
        "/route", calculate_guardian_safe_route, methods=["POST"], include_in_schema=False
    )
    app.include_router(direct_guardian_router)
    app.include_router(dashboard_router, prefix=prefix)
    app.include_router(emergency_router, prefix=prefix)
    app.include_router(activity_router, prefix=prefix)
    app.include_router(notifications_router, prefix=prefix)
    app.include_router(achievements_router, prefix=prefix)
    app.include_router(fake_tools_router, prefix=prefix)
    app.include_router(safety_router, prefix=prefix)
    app.include_router(routes_router, prefix=prefix)
    app.include_router(weather_router, prefix=prefix)
    app.include_router(ai_router, prefix=prefix)
    app.include_router(intelligence_router, prefix=prefix)

    return app


app = create_app()
