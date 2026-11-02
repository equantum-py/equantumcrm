# Fase 05 · Segunda entrega: colector de Freelancer

Fecha: 02/11/2026. Rama aislada `claude/arm-colector-freelancer`, construida sobre el PR #7 porque usa Agent Control. **Sin tarea recurrente, sin despliegue, sin ofertas ni contactos.**

## 1. Plan de implementación

| Paso | Qué hace | Dónde |
|---|---|---|
| Ejecución manual | `bin/rails agents:collect_freelancer` (opciones `DRY_RUN=1`, `BY=correo`, `MAX_REQUESTS=10`) | `lib/tasks/agents.rake` |
| Autorización | Antes de leer: `Agent.authorize!("prospect_scout", "read_public_sources")`. Antes de registrar: `ingest_leads`, comprobado otra vez por cada prospecto (si se apaga el agente a mitad de la ejecución, se detiene) | `Collectors::Freelancer#call` |
| Consulta | API pública `GET /api/projects/0.1/projects/active/` con `query`, `languages[]=es`, `job_details`, `full_description`. Sin inicio de sesión ni scraping | `Collectors::Freelancer#fetch` |
| Filtrado por servicios | Solo proyectos abiertos, públicos, que no sean contratación directa, y con al menos una habilidad de Freelancer que corresponda a un servicio eQuantum (tabla `JOB_SERVICES`) | `Collectors::Freelancer.normalize` |
| Normalización | Título, descripción (máx. 2.000), URL del proyecto, `external_id = freelancer:<id>`, fecha de publicación (verificada por la API), presupuesto publicado como texto con moneda y tipo, cantidad de ofertas, cierre estimado (publicación + período de ofertas), canal "mensaje de plataforma" | idem |
| Evidencia y fecha | Una evidencia "page_snapshot" con fecha de captura, título, presupuesto, ofertas y habilidades | idem |
| Duplicados | Dentro de la ejecución, por id de proyecto. Contra el CRM, por la huella de URL canónica de `LeadIngestion`: si ya existe, cuenta como duplicado y no se crea nada | `LeadIngestion` (sin cambios) |
| Ingesta | `LeadIngestion` existente: queda **sin verificar**, estado "nuevo", canal "Agentes (API)", sin puntaje. Se vinculan los servicios detectados | `Collectors::Freelancer#ingest` |
| Agent Control | Cada ejecución registra agente, quién la lanzó, inicio, duración, fuente, consultas, proyectos leídos, nuevos, duplicados, errores sanitizados y pendientes de aprobación (= nuevos sin verificar) | `AgentRun.track` |
| Límite de solicitudes | Máximo 10 consultas por ejecución (configurable), 2 segundos mínimo entre consultas, 20 resultados por consulta, 15 s de espera máxima | `DEFAULTS` |
| Manejo de errores | Un 429 detiene la ejecución y queda registrado. Un error HTTP, de red o de JSON se registra y sigue con la siguiente consulta. Si **ninguna** consulta funciona, la ejecución queda como fallida | idem |
| Pruebas | 13 pruebas con respuestas simuladas (sin red): normalización, filtros, ingesta, duplicados, simulación, límites, 429, errores, agente apagado, acción no permitida, ausencia de tarea recurrente | `test/services/collectors/freelancer_test.rb` |

## 2. Estado
- Implementado y probado: suite completa 144 pruebas en verde, RuboCop y Brakeman sin avisos.
- **Prueba real en modo simulación** (02/11/2026, base local, sin registrar nada): 4 consultas, 25 proyectos leídos, 13 de servicios eQuantum. Ejemplos: "Construcción Tienda Online Moda" (EUR 250–750, fijo), "Configurar Pixel Meta Shopify" (USD 10–30, fijo).
- `prospect_scout` sigue **desactivado** en las semillas. Activarlo es una decisión de Dirección. Hasta entonces el comando responde "No autorizado".
- El agente figura en Agent Control como "manual" cuando se active, nunca como "programado". `config/recurring.yml` no lo incluye (hay una prueba que lo verifica).

## 3. Limitaciones conocidas
- La API pública **no informa el país del cliente**. El prospecto queda sin país; no se infiere de la moneda.
- La correspondencia habilidad → servicio es una regla fija. Puede traer falsos positivos (ej.: "Mobile App Testing"); por eso todo entra sin verificar.
- Detrás de un proxy, Ruby necesita `http_proxy`/`https_proxy` y el certificado del proxy. En un servidor normal no hace falta.
- Si el agente se apaga a mitad de una ejecución, los prospectos ya creados quedan (sin verificar) y la ejecución figura como fallida.

## 4. Siguiente paso (requiere orden de Dirección)
1. Activar `prospect_scout` y correr una ejecución manual real.
2. Revisar los prospectos creados en "Sin verificar".
3. Decidir hosting (ver [11-infraestructura-agentes.md](11-infraestructura-agentes.md)) antes de cualquier ejecución programada.
