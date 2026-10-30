# 01 — Arquitectura del ecosistema

Estado: **propuesta para aprobación de Dirección**. Nada de esto está implementado todavía.

## 1. Principios

1. **Un solo sistema de registro.** Rails es dueño de todos los datos comerciales (empresas, contactos, prospectos, oportunidades, propuestas, actividades). Python nunca escribe directo en la base de datos.
2. **El CRM funciona sin IA.** Todo lo que hace Prospect AI también se puede hacer a mano en el CRM. La IA acelera, no es requisito.
3. **La IA propone, una persona decide.** Toda salida de IA se guarda como `ai_analysis` con estado `pending_review`. Ningún registro crítico cambia sin validación (de reglas y, cuando corresponde, humana).
4. **Monolito modular, no microservicios.** Dos servicios desplegables (Rails y Python) porque tienen ciclos y dependencias distintos. Nada más.
5. **Sin lógica duplicada.** Cada regla de negocio vive en un solo lugar (tabla en la sección 4).

## 2. Vista general

```
                   ┌──────────────────────────────────────────────┐
  Usuarios ───────▶│  eQuantum CRM (Rails 8)                      │
  (navegador)      │  Hotwire · Tailwind · Auth · Roles · Auditoría│
                   │                                              │
  Captura manual ─▶│  API interna /api/v1 (token + idempotencia)  │◀── Skills de Claude
  (formulario,     │                                              │    (vía API o manual)
   bookmarklet)    │  Jobs en segundo plano (Solid Queue)         │
                   └───────┬───────────────────────▲──────────────┘
                           │ POST /v1/analyze      │ POST /api/v1/lead_ingestions
                           ▼                       │
                   ┌───────────────────────────────┴──────────────┐
                   │  Prospect AI (Python · FastAPI · Pydantic)   │
                   │  normalización · clasificación · propuesta de│
                   │  criterios de puntuación · huella anti-dup   │
                   │  conectores de fuentes autorizadas           │
                   └───────────────┬──────────────────────────────┘
                                   │ (opcional, con clave aprobada)
                                   ▼
                          Proveedor de modelo de IA
                   PostgreSQL ◀── solo Rails
```

## 3. Componentes

### 3.1 eQuantum CRM — `apps/crm/` (Fase 02)

| Aspecto | Decisión |
|---|---|
| Framework | Ruby on Rails 8.x, Ruby 3.3 |
| Base de datos | PostgreSQL 16+ |
| Frontend | Hotwire (Turbo + Stimulus), Tailwind CSS, importmap (sin bundler de Node) |
| Autenticación | Generador de autenticación nativo de Rails 8 (`has_secure_password`, sesiones en BD). Sin Devise salvo necesidad concreta |
| Autorización | Pundit, con políticas por rol y por registro (responsable) |
| Jobs | **Solid Queue** (recomendado, sin Redis). Sidekiq + Redis solo si el volumen lo justifica |
| Auditoría | Tabla `audit_logs` propia escrita desde un concern de modelo |
| PDF de propuestas | Fase 05. Evaluar Prawn (Ruby puro) frente a Grover/Chromium |
| Pruebas | Minitest + system tests (Capybara) |
| Calidad | RuboCop (rails-omakase), Brakeman, bundler-audit |

¿Por qué Solid Queue y no Sidekiq? Rails 8 lo trae por defecto, guarda los trabajos en PostgreSQL y evita operar y pagar Redis. Nuestro volumen previsto (cientos a pocos miles de jobs por día) está holgadamente dentro de su capacidad. Es una decisión reversible: ActiveJob permite cambiar de backend sin reescribir los jobs.

### 3.2 Prospect AI — `services/prospect-ai/` (Fase 03)

| Aspecto | Decisión |
|---|---|
| Lenguaje | Python 3.12+ |
| API | FastAPI + Pydantic v2 |
| Estado | **Sin base de datos propia.** Recibe, procesa y devuelve. Lo persistente vive en Rails |
| Responsabilidades | Normalizar texto, detectar idioma y país probable, clasificar servicio, proponer valores por criterio de puntuación con justificación, calcular huella para deduplicación, conectores de fuentes autorizadas |
| IA | Interfaz `ModelProvider` con implementación "reglas" (sin costo, por defecto) y una implementación con LLM activable por variable de entorno cuando Dirección apruebe el gasto |
| Pruebas | pytest, contratos validados contra el JSON Schema compartido |
| Calidad | ruff, mypy |

### 3.3 Skills de Claude — `skills/`

Ocho Skills que guían a Claude cuando un usuario trabaja con él (en Claude Code o claude.ai). No corren solas. Cuando una Skill necesita guardar algo, lo hace a través de la API del CRM o entregando un bloque listo para cargar a mano. Ver `05-skills.md`.

### 3.4 Automatizaciones (Fase 05)

- Tareas periódicas internas (recordatorios, resúmenes, alertas): jobs recurrentes de Solid Queue dentro de Rails.
- n8n: solo si se necesitan flujos con herramientas externas (correo, Slack, Google Sheets). Autohospedado (licencia "Sustainable Use", uso interno permitido). Se decide en Fase 05.
- Ninguna automatización envía mensajes a prospectos sin aprobación explícita por mensaje.

## 4. Dónde vive cada regla (anti-duplicación)

| Regla | Dueño | El otro servicio... |
|---|---|---|
| Rúbrica de puntuación (criterios, máximos, umbrales) | Rails (tabla `scoring_criteria`, editable en Administración) | Python la recibe en cada solicitud; no la tiene hardcodeada |
| Suma de la puntuación y clasificación (muy alta/alta/media/baja) | Rails | Python solo propone el valor de cada criterio con su justificación |
| Interpretar texto libre y proponer criterios | Python | Rails no interpreta texto |
| Huella de deduplicación (algoritmo) | Python calcula; Rails impone unicidad con índice único | Rails no recalcula, valida formato |
| Transiciones de etapa del pipeline | Rails | Python nunca cambia etapas |
| Catálogos (servicios, países, fuentes) | Rails | Python recibe los códigos válidos en la solicitud |
| Tarifas y precios | Rails (`service_rates`) | Ni Python ni las Skills inventan precios |

## 5. Estructura del repositorio (validada)

```
equantumcrm/
├── apps/crm/                 # Rails (se crea en Fase 02, no antes)
├── services/prospect-ai/     # FastAPI (se crea en Fase 03, no antes)
├── skills/                   # 8 Skills (fuente de verdad)
├── contracts/                # JSON Schema compartido Rails ⇄ Python (Fase 03)
├── docs/                     # Arquitectura, decisiones, planes
├── infrastructure/           # docker compose de desarrollo, despliegue (Fase 02/06)
├── scripts/                  # Utilidades del repo (validación de skills)
├── .github/workflows/        # CI por componente con filtros de ruta
└── README.md
```

Cambios respecto de la propuesta original:

- Se agrega `contracts/` para que el contrato de integración tenga un solo origen y ambos lados se prueben contra él.
- No se crean carpetas vacías: `apps/`, `services/`, `contracts/` e `infrastructure/` aparecen cuando tengan contenido real.
- `skills/` se mantiene en la raíz como fuente de verdad. Para usarlas en Claude Code se copian o enlazan a `.claude/skills/`; para claude.ai se empaquetan en zip. Ver `05-skills.md`.

## 6. Seguridad (base desde el día uno)

- Contraseñas con bcrypt (`has_secure_password`). Nunca en texto plano.
- Secretos solo en variables de entorno o Rails credentials. `.env` en `.gitignore`. Escaneo de secretos en CI.
- CSRF activo (por defecto en Rails) para la UI; la API usa token Bearer y no comparte sesión de navegador.
- SQL: solo consultas parametrizadas de ActiveRecord; prohibido interpolar entrada del usuario en SQL.
- Autorización por política en cada controlador (Pundit `verify_authorized`).
- API entre servicios: token por cliente guardado como digest (tabla `api_clients`), alcance limitado (`leads:write`, `analysis:write`), cabecera `Idempotency-Key` obligatoria, límite de tasa (Rack::Attack).
- Validación de datos externos en ambos extremos (Pydantic en Python, validaciones de modelo y JSON Schema en Rails).
- Auditoría de altas, cambios, borrados, inicios de sesión y exportaciones.
- Datos personales mínimos y política de retención (ver `02-modelo-de-datos.md`, sección 6).
- Sesiones con cookie `httponly`, `secure`, `SameSite=Lax` y expiración.

## 7. Infraestructura y despliegue (evaluación, sin contratar nada)

| Opción | Corre Rails + jobs + Postgres | Corre Python | Observación |
|---|---|---|---|
| VPS propio + Kamal (Rails 8) | Sí | Sí (como otro servicio Kamal) | Menor costo recurrente; requiere operar el servidor. Recomendado para producción |
| Render / Railway / Fly.io | Sí | Sí | Más simple; costo mayor por servicio y por base de datos. Bueno para staging |
| Vercel | **No** para Rails ni jobs persistentes | Parcial (funciones serverless) | No sirve para esta arquitectura |
| GitHub Codespaces | Desarrollo, no producción | — | Útil para desarrollar sin instalar nada |

Los precios cambian a menudo; se cotizarán con fecha en la Fase 06 separando desarrollo, alojamiento, almacenamiento, procesamiento e IA. Hasta entonces todo corre local o en CI (gratis para repos privados dentro de la cuota de GitHub Actions).
