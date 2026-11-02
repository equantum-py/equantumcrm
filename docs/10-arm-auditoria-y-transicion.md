# Fase 05 · De CRM a eQuantum ARM (Agentic Relationship Management)

Fecha: 02/11/2026. Base: `main` en `9b5cc98` (PR #1–#5 integrados).

## 1. Auditoría inicial

### 1.1 Estado real del repositorio
| Punto | Estado verificado |
|---|---|
| `main` | `9b5cc98`, incluye Fases 01–04 y la ficha comercial |
| PR abiertos | **#6** (borrador): prueba de piloto con datos sintéticos, solo test. No interfiere con esta fase |
| Pruebas CRM | 102 pruebas en verde antes de esta fase (Rails 8.1, PostgreSQL 16) |
| Prospect AI | FastAPI sin base de datos. `POST /v1/analyze` y `POST /v1/ingest`. Analiza texto que se le envía: **no busca ni lee fuentes por sí mismo** |
| Trabajos en segundo plano | Solid Queue configurado solo en producción. `config/recurring.yml` tiene únicamente la limpieza de trabajos terminados. **No hay ninguna tarea comercial programada** |
| Único "agente" que existe hoy | `AnalyzeLeadJob`: pide a Prospect AI un análisis de un prospecto y lo deja pendiente de revisión |
| Producción | No hay despliegue. No se tocó ninguna base real |

### 1.2 Módulos reutilizables (sin cambios de fondo)
| Módulo actual | Módulo ARM | Por qué se reutiliza |
|---|---|---|
| Prospectos, evidencia, huella de duplicados, verificación | Prospect AI | Ya separa "detectado" de "verificado" y evita duplicados por URL canónica |
| API `POST /api/v1/lead_ingestions` + `ApiClient` | Prospect AI | Entrada única para agentes: token con alcance, idempotencia, auditoría |
| Rúbrica, puntaje, prioridad comercial, análisis IA pendientes | Sales Intelligence | La IA propone, una persona acepta; Rails calcula el puntaje final |
| Tarifas con aprobación, umbrales | Sales Agent | Base para que un borrador nunca invente precios |
| Empresas, pipeline, actividades | Relationship Hub | Sin cambios |
| Roles, permisos (Pundit), auditoría | Agent Control | Trazabilidad y permisos por rol ya existen |

### 1.3 Módulos que deben evolucionar
- **Ejecución de agentes:** falta un registro de ejecuciones y un interruptor por agente. *(Resuelto en esta entrega: Agent Control).*
- **Captación:** el dashboard mostraba el embudo histórico, no el trabajo pendiente de hoy. *(Resuelto: dashboard de captación).*
- **Fuentes:** no existe ningún colector. Prospect AI necesita conectores por fuente (API pública o datos abiertos).
- **Borradores comerciales:** las propuestas se arman fuera del sistema (archivos en la carpeta del proyecto).
- **Seguimiento:** las actividades existen, pero nada sugiere el próximo paso.

### 1.4 Seguridad de las integraciones
| Integración | Control actual | Riesgo / pendiente |
|---|---|---|
| Agentes → CRM (API de ingesta) | Token con prefijo, solo digest SHA-256 guardado, alcance `leads:ingest`, Idempotency-Key, límite de tamaño, todo entra "sin verificar" | Un token por agente para poder atribuir ejecuciones (segunda entrega) |
| CRM → Prospect AI | Bearer token; Prospect AI falla cerrado sin token | Sin TLS en desarrollo; en producción, red privada o HTTPS obligatorio |
| Fuentes externas | Ninguna integrada | Usar solo APIs públicas o datos abiertos permitidos. **Workana y BCP están detrás de Cloudflare: no se evaden.** Freelancer (API pública), DNCP, SECOP (datos.gov.co) son viables |
| Acciones comerciales | Nadie puede enviar desde el sistema | Nuevo: `Agent::FORBIDDEN_ACTIONS` impide asignar a un agente enviar, contactar, comprometer precios, contratar o gastar |

### 1.5 Cómo ejecutar agentes y tareas recurrentes
- **Recomendado:** Solid Queue (ya es dependencia, sin Redis) con tareas en `config/recurring.yml` y un proceso worker siempre encendido (`bin/jobs` o `SOLID_QUEUE_IN_PUMA`). Cada tarea llama a un job que envuelve su trabajo en `AgentRun.track`.
- **Condición para llamarlo autónomo:** que el worker corra en un servidor. **Hoy no hay servidor desplegado: ningún agente es autónomo todavía.** Las búsquedas hechas por Claude en una sesión abierta no cuentan como agentes del sistema.
- **Claude como redactor:** opcional y posterior. Requiere una clave de API en el servidor y presupuesto aprobado (gasto).

### 1.6 Dependencias y riesgos
| Riesgo | Mitigación |
|---|---|
| No hay hosting para el worker | Decidir hosting antes de la segunda entrega (gasto: requiere aprobación) |
| Fuentes con bloqueo anti-bots | Solo fuentes con API o datos abiertos; captura asistida para el resto |
| Cambios en APIs públicas | Cada conector registra errores en `agent_runs`; un error no detiene a los demás |
| Datos reales vs. sintéticos | Seguir sin importar datos reales hasta tener entorno autorizado |
| Costo de un modelo de IA para borradores | Fuera de esta fase; requiere aprobación |

## 2. Plan de transición CRM → ARM

| Entrega | Contenido | Estado |
|---|---|---|
| **1** | Auditoría, plan, identidad eQuantum ARM, dashboard de captación, Agent Control (modelo + vista), `AnalyzeLeadJob` registrando ejecuciones | **Este PR** |
| 2 | Primer colector programado (Freelancer API pública → ingesta), token por agente, ejecución programada con Solid Queue, resultados vinculados a prospectos, botón "ejecutar ahora" con permiso | Pendiente |
| 3 | Sales Agent: borradores de mensaje/propuesta con tarifas aprobadas, aprobación explícita antes de cualquier uso | Pendiente |
| 4 | Asesor de seguimiento: sugerencias sobre oportunidades sin actividad | Pendiente |

## 3. Diseño de Agent Control (implementado en esta entrega)

**Tablas**
- `agents`: `key`, `name`, `area` (prospect_ai · sales_intelligence · sales_agent · relationship_hub), `description`, `enabled` (interruptor), `execution_mode` (manual · scheduled), `schedule`, `allowed_actions` (lista cerrada), `implemented_by` (clase que hace el trabajo).
- `agent_runs`: agente, `status` (running · succeeded · failed · skipped), `trigger` (manual · scheduled · event · api), `started_at`, `finished_at` (duración), `source_key`, `source_url`, `summary`, `leads_detected`, `duplicates`, `errors_count`, `error_messages`, `pending_approvals`, `subject` (prospecto u oportunidad), `triggered_by`.

**Reglas**
- Acciones permitidas: leer fuentes públicas autorizadas, registrar prospectos sin verificar, proponer análisis, redactar borradores, sugerir seguimientos.
- Acciones imposibles de asignar (validación del modelo): enviar propuestas, contactar clientes, comprometer precios, contratar servicios, realizar gastos.
- Estado honesto: un agente solo figura como "Programado" si está activo, tiene clase que lo implementa y frecuencia definida. Sin implementación figura "Diseñado, sin implementar".
- Catálogo inicial: solo `lead_analyst` (envuelve `AnalyzeLeadJob`, que ya existía) arranca activo. Los demás arrancan desactivados.
- Permiso nuevo `agents.read` (administrador, gerente, analista).

**Vista `/agent_control`**: agentes con estado y acciones permitidas, últimas ejecuciones con todos los campos, pendientes de aprobación, límites de seguridad.

## 4. Qué falta para tener agentes operativos
1. Servidor con worker de Solid Queue encendido (decisión y gasto de Dirección).
2. Primer colector real (Freelancer API pública) con su tarea en `recurring.yml`.
3. Token de API por agente y enlace `agent_runs` ↔ `ingestion_requests` para contar prospectos y duplicados por ejecución.
4. Permiso `agents.manage` y pantalla para activar/desactivar y ejecutar a pedido, con auditoría.
5. Notificación de errores repetidos.
