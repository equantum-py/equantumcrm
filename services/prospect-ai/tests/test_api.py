import json

import httpx
import pytest

from app.crm_client import CrmClient
from app.main import app, get_crm_client

INGEST = {
    "source": "freelance_other",
    "original_url": "https://www.freelancer.com/projects/demo/sintetico-1?utm_source=x",
    "title": "Tienda online sintética",
    "text_excerpt": "Necesito   una tienda Shopify para una marca de prueba.\n Envíos a toda España.",
    "published_at": "2026-10-30T08:00:00Z",
    "published_at_verified": True,
    "country_hint": "es",
    "contact_channel": {"kind": "platform_message"},
    "published_budget_text": "EUR 250-750",
    "evidence": [{"kind": "post_excerpt", "captured_at": "2026-10-30T09:00:00Z"}],
}


def use_crm(settings, handler, sleeps=None):
    transport = httpx.MockTransport(handler)
    app.dependency_overrides[get_crm_client] = lambda: CrmClient(
        settings, transport=transport, sleep=(sleeps.append if sleeps is not None else lambda _s: None)
    )


def test_health_is_public(client):
    assert client.get("/health").json()["status"] == "ok"


@pytest.mark.parametrize("header", [None, "Bearer otro", "token-de-prueba-prospect-ai"])
def test_rejects_bad_tokens(client, header):
    headers = {"Authorization": header} if header else {}
    response = client.post("/v1/analyze", json={"source": "manual", "text": "x"}, headers=headers)
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "unauthorized"


def test_fails_closed_without_configured_token(client, settings):
    from app.main import get_settings

    app.dependency_overrides[get_settings] = lambda: settings.__class__(
        token=None, crm_api_url=None, crm_api_token=None
    )
    response = client.post("/v1/analyze", json={"source": "manual", "text": "x"})
    assert response.status_code == 503


def test_analyze(client, auth):
    response = client.post(
        "/v1/analyze", json={"source": "manual", "text": "Busco una landing page urgente"}, headers=auth
    )
    assert response.status_code == 200
    body = response.json()
    assert body["has_commercial_intent"] is True
    assert body["services"][0]["key"] == "landing"
    assert body["fingerprint"].startswith("sha256:")


def test_validation_errors_are_structured(client, auth):
    response = client.post("/v1/analyze", json={"source": "", "extra": 1}, headers=auth)
    assert response.status_code == 422
    details = response.json()["error"]["details"]
    assert {"source", "text", "extra"} <= set(details)


def test_ingest_normalizes_and_forwards(client, auth, settings):
    seen = {}

    def handler(request: httpx.Request):
        seen["key"] = request.headers["Idempotency-Key"]
        seen["auth"] = request.headers["Authorization"]
        seen["body"] = json.loads(request.content)
        return httpx.Response(201, json={"lead": {"id": 7}, "duplicate": False, "analysis_id": 3})

    use_crm(settings, handler)
    response = client.post("/v1/ingest", json=INGEST, headers={**auth, "Idempotency-Key": "clave-prueba-001"})
    assert response.status_code == 201
    body = seen["body"]
    assert seen["key"] == "clave-prueba-001"
    assert seen["auth"] == "Bearer token-crm-prueba"
    assert body["text_excerpt"] == "Necesito una tienda Shopify para una marca de prueba. Envíos a toda España."
    assert body["country_hint"] == "ES"
    assert body["analysis"]["services"][0]["key"] == "shopify"
    assert body["analysis"]["fingerprint"] == response.json()["fingerprint"]
    assert response.json()["canonical_url"] == "freelancer.com/projects/demo/sintetico-1"
    assert response.json()["crm"]["lead"]["id"] == 7


def test_ingest_retries_with_same_key_then_succeeds(client, auth, settings):
    keys, sleeps = [], []

    def handler(request):
        keys.append(request.headers["Idempotency-Key"])
        if len(keys) == 1:
            raise httpx.ConnectError("caído")
        if len(keys) == 2:
            return httpx.Response(503)
        return httpx.Response(200, json={"lead": {"id": 7}, "duplicate": True})

    use_crm(settings, handler, sleeps)
    response = client.post("/v1/ingest", json=INGEST, headers=auth)
    assert response.status_code == 200
    assert len(set(keys)) == 1 and len(keys) == 3
    assert sleeps == [0, 0]


def test_ingest_reports_crm_down(client, auth, settings):
    def handler(_request):
        raise httpx.ConnectError("caído")

    use_crm(settings, handler)
    response = client.post("/v1/ingest", json=INGEST, headers=auth)
    assert response.status_code == 502
    assert response.json()["error"]["code"] == "crm_unavailable"


@pytest.mark.parametrize(
    ("status", "expected_status", "code"),
    [(401, 502, "crm_auth_failed"), (409, 409, "idempotency_conflict"), (422, 422, "crm_validation_failed")],
)
def test_ingest_maps_crm_errors(client, auth, settings, status, expected_status, code):
    use_crm(settings, lambda _r: httpx.Response(status, json={"error": {"details": {"source": ["x"]}}}))
    response = client.post("/v1/ingest", json=INGEST, headers=auth)
    assert response.status_code == expected_status
    assert response.json()["error"]["code"] == code


def test_ingest_without_crm_config(client, auth):
    from app.config import Settings
    from app.main import get_settings

    app.dependency_overrides[get_settings] = lambda: Settings(
        token="token-de-prueba-prospect-ai", crm_api_url=None, crm_api_token=None
    )
    response = client.post("/v1/ingest", json=INGEST, headers=auth)
    assert response.status_code == 503
    assert response.json()["error"]["code"] == "crm_not_configured"


def test_ingest_drops_invalid_url_and_uses_text_fingerprint(client, auth, settings):
    captured = {}

    def handler(request):
        captured.update(json.loads(request.content))
        return httpx.Response(201, json={})

    use_crm(settings, handler)
    response = client.post("/v1/ingest", json={**INGEST, "original_url": "javascript:alert(1)"}, headers=auth)
    assert response.status_code == 201
    assert "original_url" not in captured
    assert response.json()["canonical_url"] is None
