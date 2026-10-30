"""Uniform error body: {"error": {"code", "message", "details"?}}."""

from fastapi import Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException


class ServiceError(Exception):
    def __init__(self, status: int, code: str, message: str, details: dict | None = None):
        super().__init__(message)
        self.status, self.code, self.message, self.details = status, code, message, details


def error_body(code: str, message: str, details: dict | None = None) -> dict:
    error = {"code": code, "message": message}
    if details:
        error["details"] = details
    return {"error": error}


async def service_error_handler(_request: Request, exc: ServiceError) -> JSONResponse:
    return JSONResponse(error_body(exc.code, exc.message, exc.details), status_code=exc.status)


async def validation_error_handler(_request: Request, exc: RequestValidationError) -> JSONResponse:
    details: dict[str, list[str]] = {}
    for item in exc.errors():
        field = ".".join(str(part) for part in item["loc"] if part != "body") or "body"
        details.setdefault(field, []).append(item["msg"])
    return JSONResponse(error_body("validation_failed", "La solicitud tiene errores", details), status_code=422)


async def http_error_handler(_request: Request, exc: StarletteHTTPException) -> JSONResponse:
    return JSONResponse(error_body("http_error", str(exc.detail)), status_code=exc.status_code)


async def unexpected_error_handler(_request: Request, _exc: Exception) -> JSONResponse:
    return JSONResponse(error_body("internal_error", "Error interno del servicio"), status_code=500)
