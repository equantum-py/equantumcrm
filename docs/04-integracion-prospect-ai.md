# 04 — Integración Prospect AI ⇄ CRM

Estado: **implementado en Fase 03** (ingesta, análisis por reglas, autenticación entre servicios). Código: `apps/crm/app/controllers/api/v1/`, `services/prospect-ai/`. Vectores de huella compartidos: `contracts/fingerprint-vectors.json`.

Diferencias con el borrador:
- La ingesta acepta un campo opcional `analysis` (salida de `/v1/analyze`). Se guarda como análisis pendiente; no puntúa ni califica.
- `422` también cuando falta `Idempotency-Key` (8 a 128 caracteres); `400` si el cuerpo no es JSON.
- Rails responde con `Idempotent-Replayed: true` cuando repite una respuesta guardada.
- Los tokens de servicio se emiten con `bin/rails api_clients:create`, se guardan solo como SHA-256 y cada acción queda en auditoría con el cliente de API.
- `AnalyzeLeadJob` pide el análisis para capturas manuales solo si `PROSPECT_AI_URL` y `PROSPECT_AI_TOKEN` están definidas.

## 1. Flujos

**A. Ingesta (fuente → CRM).** Un conector autorizado de Prospect AI, una Skill de Claude o un usuario envían una señal al CRM.

```
Python/Skill ──POST /api/v1/lead_ingestions──▶ Rails
  Rails: valida esquema → idempotencia → huella única → crea lead (status=new,
  verification_status según evidencia) → encola AnalyzeLeadJob → 201/200
```

**B. Análisis (CRM → Python → CRM).** Rails pide el análisis y guarda la propuesta para revisión.

```
AnalyzeLeadJob ──POST /v1/analyze (texto, catálogos, rúbrica vigente)──▶ Prospect AI
  ◀── servicio(s) propuesto(s), país probable, criterios con puntos y justificación,
      basis verified/inferred, huella, mensaje sugerido (borrador)
  Rails: guarda ai_analysis(status=pending_review). No toca el lead.
Usuario acepta → Rails copia criterios a lead_scores, suma, fija banda, audita.
```

El paso 9 del flujo pedido ("el usuario revisa") es obligatorio por diseño: sin aceptación humana no hay puntuación oficial ni paso al pipeline.

## 2. Contrato de ingesta (borrador)

`POST /api/v1/lead_ingestions`
Cabeceras: `Authorization: Bearer <token>`, `Idempotency-Key: <uuid>`, `Content-Type: application/json`.

```json
{
  "source": "facebook_group",
  "original_url": "https://www.facebook.com/groups/…/posts/…",
  "external_id": null,
  "published_at": "2026-10-28T14:05:00-03:00",
  "published_at_verified": true,
  "country_hint": "PY",
  "text_excerpt": "Busco quien me haga una tienda online para mi negocio de ropa…",
  "author_display_name": "Nombre público tal como aparece",
  "contact_channel": { "kind": "public_comment", "value": null },
  "published_budget_text": null,
  "captured_by": "skill:eq-facebook-research",
  "evidence": [{ "kind": "post_excerpt", "captured_at": "2026-10-30T15:00:00Z" }]
}
```

Respuestas: `201` creado · `200` ya existía (misma huella o misma clave de idempotencia; devuelve el lead existente) · `409` misma clave con distinto cuerpo · `422` error de validación con detalle por campo · `401/403` token inválido o sin alcance · `429` límite de tasa.

## 3. Contrato de análisis (borrador)

`POST /v1/analyze` (Prospect AI). Autenticación: token de servicio en cabecera; red privada en producción.

Respuesta (resumen):
```json
{
  "engine_version": "rules-0.1.0",
  "fingerprint": "sha256:…",
  "language": "es",
  "country_guess": { "value": "PY", "basis": "inferred", "reason": "menciona Asunción" },
  "services": [{ "key": "ecommerce", "confidence": 0.86 }],
  "has_commercial_intent": true,
  "criteria": [
    { "key": "explicit_intent", "points": 25, "basis": "verified", "justification": "Dice 'busco quien me haga'" },
    { "key": "budget", "points": 0, "basis": "verified", "justification": "No publica presupuesto" }
  ],
  "suggested_next_action": "Responder en el hilo pidiendo detalles del catálogo",
  "draft_message": "…",
  "warnings": ["Fecha de publicación no visible en el extracto"]
}
```

Reglas: los puntos de cada criterio no superan el máximo enviado por Rails; `basis` es obligatorio; si falta un dato, `points = 0` y se explica, nunca se supone.

## 4. Robustez

- Reintentos con backoff exponencial en el job; la idempotencia evita duplicados.
- Timeouts cortos (10 s análisis por reglas; 60 s con LLM).
- Errores registrados en `ai_analyses.error` e `integrations.last_error`; alerta interna si fallan N seguidos.
- Si Prospect AI no responde, el lead queda creado y calificable a mano (el CRM no depende de la IA).
- Versionado del contrato por ruta (`/v1`). Pruebas de contrato en CI en ambos lados contra `contracts/*.schema.json`.
