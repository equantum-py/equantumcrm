"""Sends normalized leads to the Rails ingestion API with retries.

The same Idempotency-Key is reused on every retry, so a request that
reached Rails before a timeout is never created twice.
"""

import time

import httpx

from .config import Settings
from .errors import ServiceError

RETRYABLE_STATUS = {429, 500, 502, 503, 504}


class CrmClient:
    def __init__(self, settings: Settings, transport: httpx.BaseTransport | None = None, sleep=time.sleep):
        if not settings.crm_api_url or not settings.crm_api_token:
            raise ServiceError(503, "crm_not_configured", "Falta CRM_API_URL o CRM_API_TOKEN")
        self.settings = settings
        self.sleep = sleep
        self.http = httpx.Client(
            base_url=settings.crm_api_url,
            timeout=settings.crm_timeout,
            transport=transport,
            headers={"Authorization": f"Bearer {settings.crm_api_token}"},
        )

    def ingest(self, payload: dict, idempotency_key: str) -> tuple[int, dict]:
        last_error = "sin respuesta"
        for attempt in range(1, self.settings.crm_attempts + 1):
            try:
                response = self.http.post(
                    "/api/v1/lead_ingestions", json=payload, headers={"Idempotency-Key": idempotency_key}
                )
            except httpx.TransportError as exc:
                last_error = type(exc).__name__
            else:
                if response.status_code not in RETRYABLE_STATUS:
                    return self._result(response)
                last_error = f"HTTP {response.status_code}"
            if attempt < self.settings.crm_attempts:
                self.sleep(self.settings.crm_backoff * 2 ** (attempt - 1))
        raise ServiceError(
            502, "crm_unavailable", f"El CRM no respondió tras {self.settings.crm_attempts} intentos ({last_error})"
        )

    def _result(self, response: httpx.Response) -> tuple[int, dict]:
        try:
            body = response.json()
        except ValueError:
            body = {}
        if response.status_code in (401, 403):
            raise ServiceError(502, "crm_auth_failed", "El CRM rechazó el token de servicio")
        if response.status_code == 409:
            raise ServiceError(409, "idempotency_conflict", "El CRM ya recibió esa Idempotency-Key con otro contenido")
        if response.status_code == 422:
            details = body.get("error", {}).get("details") if isinstance(body, dict) else None
            raise ServiceError(422, "crm_validation_failed", "El CRM rechazó los datos", details)
        if response.status_code not in (200, 201):
            raise ServiceError(502, "crm_unexpected_response", f"El CRM respondió HTTP {response.status_code}")
        return response.status_code, body
