# Prospect AI

Servicio sin estado (FastAPI + Pydantic) que analiza publicaciones y las envía al CRM. No tiene base de datos: Rails es el sistema de registro y el dueño de la puntuación final.

## Endpoints

| Método | Ruta | Qué hace |
|---|---|---|
| GET | `/health` | Estado y versión del motor. Sin autenticación |
| POST | `/v1/analyze` | Propone servicios, país, intención, puntos por criterio, siguiente acción y borrador. No guarda nada |
| POST | `/v1/ingest` | Normaliza, analiza y envía el prospecto a `POST /api/v1/lead_ingestions` del CRM con el análisis adjunto |

Autenticación: `Authorization: Bearer $PROSPECT_AI_TOKEN`. Sin token configurado, el servicio responde 503 a todo (falla cerrado).

Errores: siempre `{"error": {"code", "message", "details"?}}`. Si el CRM no responde tras los reintentos, devuelve 502 `crm_unavailable`. Si el CRM rechaza el token, devuelve 502 `crm_auth_failed`.

## Reglas del motor (`rules-0.1.0`)

- Solo propone. El CRM guarda el análisis como pendiente y una persona lo acepta o lo rechaza.
- Si falta un dato, propone 0 puntos y lo explica. No supone presupuestos, fechas ni países.
- El criterio de presupuesto nunca da el máximo: la compatibilidad depende de tarifas aprobadas, que solo conoce el CRM.
- Un criterio sin regla recibe 0 y una advertencia (así una rúbrica nueva no rompe el servicio).
- La huella (`sha256:`) es idéntica a la de Rails; `contracts/fingerprint-vectors.json` lo prueba en ambos lados.

## Desarrollo

```bash
python -m venv .venv && . .venv/bin/activate
pip install -r requirements-dev.txt
pytest -q && ruff check . && ruff format --check .
cp .env.example .env   # completar tokens; nunca subirlos al repositorio
uvicorn app.main:app --port 8000
```

El token para `CRM_API_TOKEN` se emite en el CRM con `bin/rails api_clients:create NAME=prospect-ai` y se muestra una sola vez.
