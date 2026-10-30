---
name: eq-lead-qualifier
description: Califica oportunidades comerciales de eQuantum con la rúbrica oficial de 100 puntos, separando datos verificados de inferencias, detecta duplicados y asigna banda (muy alta, alta, media, baja). Usar cuando haya leads, publicaciones o hallazgos que puntuar, priorizar o deduplicar antes de cargarlos al CRM.
---

# eq-lead-qualifier

## Principios
- La puntuación debe ser explicable criterio por criterio.
- Cada criterio lleva `basis: verified` (se ve en la fuente) o `basis: inferred` (deducción razonada). Ante falta de datos: 0 puntos y explicar. Nunca completar con suposiciones.
- La rúbrica oficial vive en el CRM (Administración → Criterios). `references/rubrica.md` es la versión 1; si el CRM tiene otra versión vigente, usar la del CRM.

## Proceso
1. Leer cada hallazgo (formato `eq-lead-hunter`).
2. Comprobar intención real de contratación. Si no la hay, descartar con motivo y no puntuar.
3. Puntuar los 8 criterios según `references/rubrica.md`.
4. Sumar y asignar banda: 80–100 muy alta, 60–79 alta, 40–59 media, 0–39 baja.
5. Duplicados: misma URL canónica (sin parámetros, sin `m.`/`www.`), mismo autor y texto casi igual en otra URL, o lead ya existente en el CRM. Marcar `possible_duplicate_of` y no crear otro.
6. Ordenar por puntuación y recomendar a cuáles dedicar tiempo hoy.

## Salida por lead
```yaml
original_url: ...
criteria:
  - {key: explicit_intent, points: 25, basis: verified, justification: "..."}
  - ...
score: 72
band: high
possible_duplicate_of: null
recommendation: "Responder hoy en el hilo; pedir catálogo y plazos"
```

## Carga en el CRM
Para pegar en "Análisis de Claude" (captura rápida o ficha del prospecto), entregar además este JSON. El CRM lo guarda como propuesta pendiente y calcula la puntuación final al aceptarlo.
```json
{"services": ["ecommerce"], "country": "PY",
 "criteria": [{"key": "explicit_intent", "points": 25, "basis": "verified", "justification": "..."}],
 "recommended_action": "...", "draft_message": "borrador de eq-sales-copywriter"}
```
Claves de servicio y de criterio válidas: las del catálogo del CRM (ver `references/rubrica.md`).
