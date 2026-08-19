from __future__ import annotations

import logging
import sys
import uuid
from typing import Any

try:
    import structlog
    from structlog.types import EventDict, Processor
    HAS_STRUCTLOG = True
except ImportError:
    structlog = None  # type: ignore
    HAS_STRUCTLOG = False

from app.core.config import get_settings

settings = get_settings()


def _add_request_id(
    logger: Any, method: str, event_dict: Any
) -> Any:
    """Inject request_id if present in context vars."""
    try:
        from app.core.dependencies import request_id_ctx

        event_dict["request_id"] = request_id_ctx.get("")
    except Exception:
        pass
    return event_dict


def configure_logging() -> None:
    """Configure structured JSON logging for the application."""
    if not HAS_STRUCTLOG:
        logging.basicConfig(
            level=logging.DEBUG if settings.app_debug else logging.INFO,
            format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
            stream=sys.stdout,
        )
        return

    shared_processors: list[Processor] = [
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.add_log_level,
        structlog.stdlib.add_logger_name,
        structlog.processors.TimeStamper(fmt="iso"),
        _add_request_id,
    ]

    if settings.is_production:
        renderer = structlog.processors.JSONRenderer()
    else:
        renderer = structlog.dev.ConsoleRenderer(colors=True)

    structlog.configure(
        processors=shared_processors + [
            structlog.stdlib.ProcessorFormatter.wrap_for_formatter,
        ],
        logger_factory=structlog.stdlib.LoggerFactory(),
        wrapper_class=structlog.stdlib.BoundLogger,
        cache_logger_on_first_use=True,
    )

    formatter = structlog.stdlib.ProcessorFormatter(
        processor=renderer,
        foreign_pre_chain=shared_processors,
    )

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(formatter)

    root_logger = logging.getLogger()
    root_logger.addHandler(handler)
    root_logger.setLevel(logging.DEBUG if settings.app_debug else logging.INFO)

    # Quiet noisy libraries
    logging.getLogger("sqlalchemy.engine").setLevel(
        logging.INFO if settings.app_debug else logging.WARNING
    )
    logging.getLogger("asyncio").setLevel(logging.WARNING)


def get_logger(name: str = "guardian_ai") -> Any:
    if HAS_STRUCTLOG:
        return structlog.get_logger(name)
    return logging.getLogger(name)
