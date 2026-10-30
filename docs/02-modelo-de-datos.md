# 02 — Modelo de datos

Estado: **diseño**. Las migraciones se crean en Fase 02 (núcleo) y Fase 03/05 (resto), después de la aprobación.

Convenciones: PostgreSQL, claves primarias `bigint` autoincrementales, `created_at`/`updated_at` en todas las tablas, claves foráneas con `ON DELETE RESTRICT` salvo indicación, montos en unidades menores (`*_cents` bigint) + `currency` ISO 4217, enums de Rails respaldados por `string` con restricción `CHECK`.

## 1. Revisión de la lista inicial de entidades

| Entidad propuesta | Decisión | Motivo |
|---|---|---|
| users, roles, permissions | Se mantienen + `role_permissions` | Un rol por usuario al inicio; permisos como datos para poder ajustar sin desplegar |
| companies, contacts | Se mantienen | |
| leads | Se mantiene como **señal detectada** (antes del pipeline) | Separa "lo que encontramos" de "lo que negociamos" |
| lead_sources | Se renombra a **`sources`** (catálogo de plataformas) | Lo usan leads y reportes, no solo leads |
| lead_evidence | Se mantiene como `lead_evidences` | Varias evidencias por lead |
| opportunities | Se mantiene como **negocio en el pipeline** | Nace al calificar un lead o a mano |
| pipeline_stages | Se mantiene | Personalizable |
| activities + tasks | **Se unifican en `activities`** con `kind` (call, meeting, task, follow_up, reminder, note) | Una tarea es una actividad con vencimiento; dos tablas duplicarían listas, filtros y recordatorios |
| proposals, proposal_items | Se mantienen | |
| services, countries | Se mantienen | |
| ai_analysis | Se renombra a `ai_analyses` (plural Rails) | |
| integrations | Se mantiene (configuración **no secreta**) + **`api_clients`** para tokens de servicio | Separar configuración de credenciales |
| audit_logs | Se mantiene | |
| — | **Nuevas:** `scoring_criteria`, `lead_scores`, `service_rates`, `ingestion_requests`, tablas puente | Ver abajo |

## 2. Diagrama (simplificado)

```
roles ─< users ──────────────┐ (owner)
roles ─< role_permissions >─ permissions
countries ─< companies ─< contacts
                │
sources ─< leads >─ countries          leads ─< lead_evidences
             │  └─< lead_scores >─ scoring_criteria
             │  └─< ai_analyses (polimórfica)
             └─(convierte a)─> opportunities >─ pipeline_stages
                                   │  >─ companies, contacts (primario)
                                   ├─< activities (polimórfica: lead/opportunity/company/contact)
                                   └─< proposals ─< proposal_items >─ services
services ─< service_rates      services >─< leads / opportunities / companies (tablas puente)
api_clients ─< ingestion_requests          audit_logs (polimórfica)
```

## 3. Tablas

### Acceso

**users**: `email` (citext, único), `password_digest`, `name`, `role_id` FK, `active` bool, `last_sign_in_at`.
**sessions** (generador Rails 8): `user_id`, `ip_address`, `user_agent`.
**roles**: `key` único (`admin`, `manager`, `sales`, `analyst`, `viewer`), `name`.
**permissions**: `key` único (p. ej. `leads.read`, `leads.write`, `proposals.approve`, `admin.manage`).
**role_permissions**: `role_id`, `permission_id`, índice único compuesto.

### Catálogos

**countries**: `iso2` (único, p. ej. `PY`), `name`, `default_currency`, `locale` (`es-PY`, `es-CL`, `es-CO`, `es-ES`), `target_market` bool, `timezone`.
**services**: `key` único (`web_corporativa`, `landing`, `ecommerce`, `shopify`, `migracion_ecommerce`, `app_web`, `sistema_empresarial`, `integraciones`, `seo`, `google_ads`, `meta_ads`, `consultoria_comercial`, `consultoria_ecommerce`, `ux_ui`, `cro`, `analitica_ga4`, `automatizacion_n8n`, `ia_negocios`, `soporte`), `name`, `active`.
**sources**: `key` único (`facebook`, `facebook_group`, `linkedin`, `google_search`, `google_maps`, `shopify_community`, `freelance_platform`, `referral`, `website_form`, `manual`), `name`, `requires_manual_capture` bool.
**pipeline_stages**: `name`, `position` (único), `kind` (`open`/`won`/`lost`), `probability` (0–100). Semilla con las 10 etapas iniciales. Restricción: exactamente una etapa `won` y una `lost` activas.
**scoring_criteria**: `key` único, `name`, `max_points`, `position`, `guidance` text, `version`. Semilla con los 8 criterios (25/20/15/15/10/5/5/5). Restricción de aplicación: la suma de `max_points` de la versión activa = 100.
**service_rates**: `service_id`, `country_id` (nulo = general), `currency`, `unit` (`proyecto`, `hora`, `mes`), `min_cents`, `max_cents`, `valid_from`, `valid_until`, `approved_by_id`. Es la **única** fuente de precios para propuestas.

### Comercial

**companies**: `legal_name` (nullable), `trade_name` (obligatorio), `sector`, `country_id`, `website`, `normalized_domain` (único parcial cuando no es nulo), `owner_id`, `notes`.
**contacts**: `company_id` (nullable), `full_name`, `job_title`, `email`, `phone`, `public_profile_url`, `lawful_basis` (`consent`, `legitimate_interest`, `contract`), `consent_at`, `do_not_contact` bool, `owner_id`, `retention_until`. Índice único parcial en (`company_id`, `lower(email)`).

**leads** (señal detectada):
- `source_id`, `country_id` (nullable si no se sabe), `company_id` (nullable), `contact_id` (nullable), `owner_id` (nullable).
- `title`, `need_summary` text, `original_url`, `external_id` (id del post si existe), `published_at` (nullable, **solo si se verificó**), `detected_at`.
- `published_budget_text` (texto literal; nunca un número inventado), `urgency` (`unknown`/`low`/`medium`/`high`).
- `verification_status` (`unverified`, `verified`, `unreachable`, `rejected`).
- `status` (`new`, `researching`, `qualified`, `discarded`, `converted`), `discard_reason`.
- `score` (0–100, nullable hasta calificar), `score_band` (`very_high`/`high`/`medium`/`low`), `scoring_version`.
- `fingerprint` (único) — hash de URL canónica o `source+external_id`, o de texto normalizado cuando no hay URL.
- `created_via` (`manual`, `api`, `skill`).
- Índices: `fingerprint` único, (`status`, `score`), (`country_id`, `detected_at`), (`source_id`, `detected_at`).

**lead_services**: `lead_id`, `service_id`, `primary` bool. Único compuesto.
**lead_evidences**: `lead_id`, `kind` (`post_excerpt`, `screenshot`, `page_snapshot`, `note`), `url`, `excerpt` (≤ 2000 caracteres, solo lo necesario para justificar la intención), `captured_at`, `captured_by_id`, `content_sha256`.
**lead_scores**: `lead_id`, `scoring_criterion_id`, `points`, `justification` text, `basis` (`verified` / `inferred`), `set_by` (`human` / `ai_accepted`). Único (`lead_id`, `scoring_criterion_id`). `CHECK points BETWEEN 0 AND max`.

**opportunities**: `name`, `company_id`, `primary_contact_id` (nullable), `lead_id` (nullable, único: un lead se convierte una vez), `pipeline_stage_id`, `owner_id`, `country_id`, `estimated_value_cents` (nullable), `currency`, `expected_close_on`, `won_at`, `lost_at`, `lost_reason`, `stage_changed_at`.
**opportunity_services**: igual que `lead_services`.
**company_services** (interés): `company_id`, `service_id`.

**activities**: `kind`, `subject_type`/`subject_id` (polimórfica), `owner_id`, `title`, `body`, `due_at`, `completed_at`, `outcome`. Índices: (`owner_id`, `completed_at`, `due_at`), (`subject_type`, `subject_id`).

**proposals**: `opportunity_id`, `number` (único, p. ej. `EQ-2026-0001`), `status` (`draft`, `in_review`, `approved`, `sent`, `accepted`, `rejected`, `expired`), `currency`, `subtotal_cents`, `discount_cents`, `tax_cents`, `total_cents`, `valid_until`, `scope` text, `deliverables` text, `exclusions` text, `timeline` text, `payment_terms` text, `approved_by_id`, `sent_at`, `version`.
**proposal_items**: `proposal_id`, `service_id`, `service_rate_id` (obligatorio salvo ítem aprobado manualmente), `description`, `quantity`, `unit_price_cents`, `total_cents`, `position`. Regla: `unit_price_cents` dentro del rango de la tarifa o `manual_price_approved_by_id` presente.

### IA e integración

**ai_analyses**: `subject_type`/`subject_id`, `kind` (`classification`, `scoring_proposal`, `audit`, `message_draft`), `provider` (`rules`, `llm:<modelo>`), `engine_version`, `input_sha256`, `output` jsonb (validado con JSON Schema), `status` (`pending_review`, `accepted`, `rejected`, `superseded`), `reviewed_by_id`, `reviewed_at`, `error`.
**api_clients**: `name`, `token_digest` (único), `scopes` text[], `active`, `last_used_at`.
**ingestion_requests**: `api_client_id`, `idempotency_key`, `request_sha256`, `response_status`, `response_body` jsonb, `resource_type`/`resource_id`. Único (`api_client_id`, `idempotency_key`). Guarda la respuesta para que un reintento devuelva lo mismo sin duplicar.
**integrations**: `key` único, `enabled`, `settings` jsonb (sin secretos), `last_success_at`, `last_error`.
**audit_logs**: `actor_type`/`actor_id` (usuario o api_client), `action`, `auditable_type`/`auditable_id`, `changes` jsonb (campos sensibles filtrados), `ip_address`, `request_id`, `created_at`. Sin `updated_at`: solo inserción.

## 4. Prevención de duplicados

1. `leads.fingerprint` único. Prospect AI calcula la huella con un algoritmo versionado: URL canónica (sin parámetros de tracking, host en minúsculas, sin `m.`/`www.`) → SHA-256; si no hay URL, texto normalizado + fuente + fecha.
2. `companies.normalized_domain` único parcial.
3. `contacts` único por (`company_id`, email en minúsculas).
4. API: `Idempotency-Key` + `ingestion_requests` evitan duplicar por reintentos.
5. Similitud difusa (mismo autor/texto parecido en otra URL): se marca como "posible duplicado" para revisión humana, no se fusiona sola.

## 5. Estados coherentes

- Lead: `new → researching → qualified → converted`; desde cualquiera a `discarded` con motivo. `converted` exige oportunidad asociada. `qualified` exige `verification_status = verified` y puntuación completa.
- Oportunidad: entrar en etapa `won` fija `won_at`; `lost` exige `lost_reason`.
- Propuesta: `sent` exige `approved`; no se edita después de `sent` (se crea nueva versión).
- `ai_analyses` nunca cambia un registro por sí sola: aceptar un análisis es una acción de usuario auditada.

## 6. Datos personales y retención

- Solo se guarda lo necesario para el contacto comercial legítimo: nombre o denominación pública, cargo, canal de contacto publicado. No se guardan fotos de perfil, listas de amigos, datos sensibles ni conversaciones privadas.
- Las evidencias guardan un extracto mínimo, no la publicación completa ni comentarios de terceros.
- `do_not_contact` bloquea en la aplicación la creación de actividades de contacto saliente.
- Retención propuesta (a aprobar): leads descartados o sin actividad se anonimizan a los 12 meses; contactos con `retention_until` vencido se anonimizan por job mensual.
- Marco aplicable a revisar con asesoría legal (no verificado en esta fase): Paraguay (confirmar la ley general de protección de datos vigente; la Ley 6534/2020 cubre datos crediticios); Chile, Ley 19.628 y su reforma;  Ley 1581 de 2012 de Colombia; RGPD y LOPDGDD en España. España (RGPD) es el régimen más exigente y fija el estándar mínimo del sistema.
