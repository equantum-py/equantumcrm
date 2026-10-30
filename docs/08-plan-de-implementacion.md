# 08 — Plan de implementación

Cada fase termina con PR, pruebas en CI, evidencia y el informe de 8 puntos. Nada se despliega sin aprobación.

## Trabajo en paralelo

```
Semana:          1     2     3     4     5     6     7     8
CRM (Rails)      [F02 fundamentos ][F05 operación         ]
Prospect AI (Py)       [F03 motor + API ]
Captación              [Prueba 10 ops][F04 fuentes reales  ]
Calidad/infra                                  [F06 staging]
```
Las semanas son estimaciones para una persona con Claude; se ajustan al ritmo de revisión.

## F02 — Fundamentos del CRM (rama `feature/crm-foundation`)
1. `rails new apps/crm -d postgresql --css tailwind` (Rails 8, importmap, Solid Queue).
2. Docker Compose de desarrollo (`infrastructure/compose.dev.yml`: Postgres; Rails local o contenedor).
3. Autenticación (generador Rails 8), roles y permisos, Pundit, auditoría.
4. AppShell, sidebar, búsqueda global básica.
5. Catálogos con semillas (países, servicios, fuentes, etapas, criterios).
6. Empresas, contactos, leads (con captura rápida y deduplicación), pipeline Kanban + tabla.
7. CI: tests, RuboCop, Brakeman, bundler-audit.
**Aceptación:** login, CRUD con permisos, mover etapas, auditoría visible, pruebas verdes.

## F03 — Prospect AI (rama `feature/prospect-ai`)
1. `services/prospect-ai` con FastAPI, Pydantic, pytest, ruff, mypy, Dockerfile.
2. `contracts/` con JSON Schema de ingesta y análisis; pruebas de contrato en ambos lados.
3. Normalización, huella, clasificación por reglas, propuesta de criterios.
4. API Rails `/api/v1/lead_ingestions` con tokens e idempotencia; job de análisis; revisión en la bandeja Prospect AI.
5. Proveedor LLM detrás de bandera (apagado hasta aprobar gasto).

## F04 — Captación real
Ejecutar `07-prueba-de-captacion.md`, medir fuentes, luego conectores oficiales aprobados (formulario web propio, Pages API de la página de eQuantum, Places API si se aprueba costo).

## F05 — Operación comercial
Actividades y recordatorios, propuestas con tarifas, PDF, reportes, alertas internas, n8n si hace falta.

## F06 — Calidad y producción
Pruebas de seguridad y responsive, staging, plan de despliegue (Kamal en VPS recomendado), cotización de costos con fecha.

## Riesgos principales
| Riesgo | Mitigación |
|---|---|
| Facebook no ofrece acceso automatizado | Captura asistida + priorizar fuentes con intención explícita (freelance, licitaciones) |
| Volumen bajo de oportunidades verificables | La prueba de 10 mide rendimiento real antes de invertir en automatizar |
| Datos personales en evidencias | Extracto mínimo, retención, `do_not_contact`, auditoría |
| Costos de IA/APIs | Motor por reglas por defecto; LLM y APIs pagas solo con aprobación |
| Alcance creciente | Criterios de aceptación por módulo y fases cerradas por PR |
