from __future__ import annotations

from typing import Any

from fastapi import HTTPException, Request, status
from fastapi.responses import JSONResponse


# ─── Base Guardian Exception ──────────────────────────────────────────────────

class GuardianException(Exception):
    """Base exception for all Guardian AI errors."""
    status_code: int = 500
    error_code: str = "INTERNAL_ERROR"
    message: str = "An unexpected error occurred."

    def __init__(self, message: str | None = None, **kwargs: Any) -> None:
        self.message = message or self.__class__.message
        for k, v in kwargs.items():
            setattr(self, k, v)
        super().__init__(self.message)


# ─── 400 Bad Request ──────────────────────────────────────────────────────────

class BadRequestError(GuardianException):
    status_code = 400
    error_code = "BAD_REQUEST"
    message = "Invalid request."


# ─── 401 Unauthorized ─────────────────────────────────────────────────────────

class UnauthorizedError(GuardianException):
    status_code = 401
    error_code = "UNAUTHORIZED"
    message = "Authentication required."


class InvalidCredentialsError(UnauthorizedError):
    error_code = "INVALID_CREDENTIALS"
    message = "Invalid email or password."


class TokenExpiredError(UnauthorizedError):
    error_code = "TOKEN_EXPIRED"
    message = "Authentication token has expired."


class InvalidTokenError(UnauthorizedError):
    error_code = "INVALID_TOKEN"
    message = "Invalid authentication token."


# ─── 403 Forbidden ────────────────────────────────────────────────────────────

class ForbiddenError(GuardianException):
    status_code = 403
    error_code = "FORBIDDEN"
    message = "You do not have permission to perform this action."


# ─── 404 Not Found ────────────────────────────────────────────────────────────

class NotFoundError(GuardianException):
    status_code = 404
    error_code = "NOT_FOUND"
    message = "Resource not found."


# ─── 409 Conflict ─────────────────────────────────────────────────────────────

class ConflictError(GuardianException):
    status_code = 409
    error_code = "CONFLICT"
    message = "Resource already exists."


class EmailAlreadyExistsError(ConflictError):
    error_code = "EMAIL_EXISTS"
    message = "An account with this email already exists."


# ─── 422 Validation ───────────────────────────────────────────────────────────

class ValidationError(GuardianException):
    status_code = 422
    error_code = "VALIDATION_ERROR"
    message = "Request validation failed."


# ─── 429 Rate Limit ───────────────────────────────────────────────────────────

class RateLimitError(GuardianException):
    status_code = 429
    error_code = "RATE_LIMIT_EXCEEDED"
    message = "Too many requests. Please try again later."


# ─── 502 / 503 External Service ───────────────────────────────────────────────

class ExternalServiceError(GuardianException):
    status_code = 502
    error_code = "EXTERNAL_SERVICE_ERROR"
    message = "An upstream service is unavailable."


class ServiceUnavailableError(GuardianException):
    status_code = 503
    error_code = "SERVICE_UNAVAILABLE"
    message = "Service temporarily unavailable."


# ─── Exception Handlers ───────────────────────────────────────────────────────

def _error_response(error_code: str, message: str, status_code: int) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content={"success": False, "error": error_code, "message": message},
    )


async def guardian_exception_handler(
    request: Request, exc: GuardianException
) -> JSONResponse:
    return _error_response(exc.error_code, exc.message, exc.status_code)


async def http_exception_handler(
    request: Request, exc: HTTPException
) -> JSONResponse:
    return _error_response("HTTP_ERROR", exc.detail, exc.status_code)


async def validation_exception_handler(
    request: Request, exc: Exception
) -> JSONResponse:
    from fastapi.exceptions import RequestValidationError

    if isinstance(exc, RequestValidationError):
        messages = [
            f"{' -> '.join(str(loc) for loc in err.get('loc', []))}: {err.get('msg', 'invalid')}"
            for err in exc.errors()
        ]
        msg = "; ".join(messages) if messages else "Request body validation failed."
        return JSONResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            content={
                "success": False,
                "error": "VALIDATION_ERROR",
                "message": msg,
                "detail": exc.errors(),
            },
        )
    return _error_response(
        "VALIDATION_ERROR",
        "Request body validation failed.",
        status.HTTP_422_UNPROCESSABLE_ENTITY,
    )


async def generic_exception_handler(
    request: Request, exc: Exception
) -> JSONResponse:
    from app.core.logging import get_logger

    log = get_logger()
    log.error("Unhandled exception", exc_info=exc, path=str(request.url))
    return _error_response("INTERNAL_ERROR", "An unexpected error occurred.", 500)
