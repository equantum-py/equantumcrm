# Coordinación con el rediseño de frontend (Codex, PR #8)

Fecha: 02/11/2026. Rama de Codex: `frontend/arm-premium-v1`. Claude no modifica esa rama ni crea otra implementación de frontend.

## Archivos compartidos
| Archivo | PR #7 (Claude) | Acción acordada |
|---|---|---|
| `views/dashboard/show.html.erb` | Colas de captación. En la revisión técnica solo cambió una tarjeta (prioridad alta confirmada + texto con estimadas) y los parámetros de los enlaces | Codex integra la presentación; Claude no hace más cambios visuales |
| `views/layouts/application.html.erb` | Identidad ARM, grupos de navegación, enlace a Agent Control | Sin cambios nuevos de Claude |
| `views/layouts/auth.html.erb` | Identidad ARM | Sin cambios nuevos de Claude |
| `views/agent_control/show.html.erb` | Pantalla de Agent Control | Codex puede rediseñarla sin alterar políticas, estados ni datos |

La rama del colector (`claude/arm-colector-freelancer`) **no toca vistas ni estilos**.

## Contrato de datos para el frontend (`DashboardMetrics`)
| Método | Significado |
|---|---|
| `to_verify` | Prospectos abiertos sin verificar (no limitado por fecha; respeta país, servicio, fuente, responsable) |
| `pending_ai_reviews` | Análisis de IA pendientes sobre prospectos abiertos |
| `high_priority_confirmed` | **Nuevo.** Prioridad alta sin oportunidad, confirmada: verificado, intención puntuada, sin IA pendiente, sin posible duplicado. Misma regla que la ficha (`Lead.priority_confirmed`) |
| `high_priority_estimated` | **Nuevo.** Prioridad alta sin oportunidad que todavía es estimada |
| `high_priority_without_opportunity` | Total de las dos anteriores. Se mantiene por compatibilidad; no presentarlo como "listo para convertir" |
| `closing_soon(limit:)`, `closing_soon_count` | Publicaciones abiertas que cierran en 7 días |
| `leads_by_channel` | Captados en el período por canal |

**Datos de prueba:** todas las métricas excluyen `Lead.test_data` (columna `leads.synthetic` o prefijo `[DEMO]`/`[SINTÉTICO]`) y las oportunidades de esos prospectos. Esto cubre la recomendación de Codex de tener una clasificación estructurada.

**Filtro de prospectos nuevo:** `priority_status=confirmed|estimated`, que se suma a `priority` y `verification`.

## Secuencia propuesta
1. Dirección aprueba y fusiona el PR #7.
2. Codex actualiza el PR #8 contra `main` y resuelve los archivos compartidos con este contrato. Si necesita otro dato, Claude lo agrega en `DashboardMetrics` sin tocar vistas.
3. El PR del colector se rebasa sobre `main`; no tiene conflictos con el frontend.
