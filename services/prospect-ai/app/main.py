"""FastAPI entry point. Stateless: no database and no commercial records."""

import hmac
import uuid
from typing import Annotated

from fastapi import Depends, FastAPI, Header, Request, Response
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException

from . import ENGINE_VERSION
from .analyzer import analyze
from .config import Settings
from .crm_client import CrmClient
from .errors import (
    ServiceError,
    http_error_handler,
    service_error_handler,
    unexpected_error_handler,
    validation_error_handler,
)
from .fingerprint import canonical_url, fingerprint, is_http_url
from .models import AnalyzeRequest, AnalyzeResponse, IngestRequest

app = FastAPI(title="eQuantum Prospect AI", version=ENGINE_VERSION, docs_url=None, redoc_url=None)
app.add_exception_handler(ServiceError, service_error_handler)
app.add_exception_handler(RequestValidationError, validation_error_handler)
app.add_exception_handler(StarletteHTTPException, http_error_handler)
app.add_exception_handler(Exception, unexpected_error_handler)


def get_settings() -> Settings:
    return Settings.from_env()


def get_crm_client(settings: Annotated[Settings, Depends(get_settings)]) -> CrmClient:
    return CrmClient(settings)


def require_token(
    settings: Annotated[Settings, Depends(get_settings)],
    authorization: Annotated[str | None, Header()] = None,
) -> None:
    if not settings.token:
        raise ServiceError(503, "not_configured", "El servicio no tiene PROSPECT_AI_TOKEN configurado")
    scheme, _, presented = (authorization or "").partition(" ")
    if scheme != "Bearer" or not hmac.compare_digest(presented.encode(), settings.token.encode()):
        raise ServiceError(401, "unauthorized", "Token ausente o inválido")


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "engine_version": ENGINE_VERSION}


@app.post("/v1/analyze", dependencies=[Depends(require_token)])
def analyze_endpoint(request: AnalyzeRequest) -> AnalyzeResponse:
    return analyze(request)


def normalize(request: IngestRequest) -> IngestRequest:
    """Trims whitespace, keeps excerpts within the CRM limit and drops unusable URLs."""
    text = " ".join(request.text_excerpt.split())
    url = request.original_url if is_http_url(request.original_url) else None
    return request.model_copy(
        update={
            "text_excerpt": text[:2000],
            "original_url": url,
            "country_hint": request.country_hint.upper() if request.country_hint else None,
            "title": " ".join(request.title.split()) if request.title else None,
        }
    )


@app.post("/v1/ingest", dependencies=[Depends(require_token)])
def ingest_endpoint(
    request: IngestRequest,
    response: Response,
    crm: Annotated[CrmClient, Depends(get_crm_client)],
    idempotency_key: Annotated[str | None, Header(min_length=8, max_length=128)] = None,
) -> dict:
    lead = normalize(request)
    analysis = analyze(
        AnalyzeRequest(
            source=lead.source,
            text=request.text_excerpt,
            original_url=lead.original_url,
            country_hint=lead.country_hint,
            published_at=lead.published_at,
            published_at_verified=lead.published_at_verified,
            published_budget_text=lead.published_budget_text,
            contact_channel_kind=lead.contact_channel.kind if lead.contact_channel else None,
            rubric=lead.rubric,
            services=lead.services,
            target_countries=lead.target_countries,
        )
    )
    # Rails fingerprints the stored excerpt, so the analysis must use the same text.
    analysis.fingerprint = fingerprint(lead.source, lead.original_url, lead.text_excerpt)
    payload = lead.model_dump(mode="json", exclude={"rubric", "services", "target_countries"}, exclude_none=True)
    payload["analysis"] = analysis.model_dump(mode="json")

    status, body = crm.ingest(payload, idempotency_key or str(uuid.uuid4()))
    response.status_code = status
    return {
        "crm": body,
        "fingerprint": analysis.fingerprint,
        "canonical_url": canonical_url(lead.original_url),
        "services": [s.key for s in analysis.services],
        "has_commercial_intent": analysis.has_commercial_intent,
        "warnings": analysis.warnings,
    }


@app.middleware("http")
async def request_id(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Request-Id"] = request.headers.get("X-Request-Id") or str(uuid.uuid4())
    return response
