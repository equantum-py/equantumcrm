# PR #8 · Revisión de Dirección e integración pendiente

Estado comprobado el 02/11/2026 mediante GitHub:

- PR #8 aprobado con observaciones; permanece en borrador, sin autorización de fusión ni despliegue.
- `main`: `9b5cc98dee0a588c6c913e4cb8ca445359329524`.
- PR #7: abierto, sin fusionar; cabeza `69a09ffa9b4f7ee0fd8fbcf6e2d39b22e4dcda22`.
- Frontend aprobado: `b8ef78aa83799fe2c289b14a8164a024aeab298e`.

La resolución de los tres archivos compartidos y la actualización contra main quedan pendientes de que main incluya el PR #7, según la secuencia indicada por Dirección. No se incorpora anticipadamente la rama de Claude, no se cambia la base del PR y no se toca su rama.

## Cambios confirmados en el PR #7

El lockfile de Claude contiene Nokogiri **1.19.6**, Loofah **2.25.3** y rails-html-sanitizer **1.7.2**. Estas versiones todavía no están en main ni en la rama del PR #8. Se heredará el lockfile de main después de incorporar el PR #7; no se creará una actualización independiente.

`DashboardMetrics` agrega `to_verify`, `pending_ai_reviews`, `high_priority_without_opportunity`, `closing_soon`, `closing_soon_count` y `leads_by_channel`. Las colas actuales ignoran fechas de captación y mantienen los filtros comerciales. Captación por canal sí utiliza el período de detección.

Agent Control usa `/agent_control`, autorización `policy(:agent_control).show?`, `Agent`, `AgentRun` y helpers de estados de Claude. Su pantalla conserva estados reales de implementación/programación, acciones permitidas, límites, última ejecución, pendientes y registros históricos. No se sustituirán esas fuentes por simulaciones.

## Resolución prevista, después del PR #7 en main

| Archivo | Conservar y combinar |
|---|---|
| `apps/crm/app/views/dashboard/show.html.erb` | Tarjetas, gráficos, pipeline, oportunidades, seguimiento, responsive y colas de captación de Claude; sin repetir la misma métrica bajo dos nombres. |
| `apps/crm/app/views/layouts/application.html.erb` | Sidebar premium, identidad, grupos de navegación, metadatos de Claude y acceso a Agent Control condicionado a su política; cierre móvil, foco y Escape de Codex. |
| `apps/crm/app/views/layouts/auth.html.erb` | Identidad y metadatos ARM de Claude con la presentación aprobada. |
| `apps/crm/app/views/agent_control/show.html.erb` | Presentación coherente y adaptable de todos los datos de Claude, sin alterar políticas, estados ni controles. |

Los conflictos se resolverán por contenido, sin seleccionar automáticamente una versión completa.

## Contrato único de métricas

La integración moverá consultas y agregaciones de `ArmDashboardHelper` y de la vista hacia `DashboardMetrics`, reutilizando sus scopes filtrados. Los helpers quedarán para formato y representación; no habrá una segunda definición de los cálculos comerciales. No se modificará el algoritmo de scoring.

| Grupo | Período y semántica |
|---|---|
| Prospectos detectados/verificados, gráficos, país, fuente y canal | Fecha de detección y filtros comerciales seleccionados. Captación agrupada en fecha local de America/Asuncion, hasta 60 intervalos. |
| Sin verificar, análisis por aprobar, prioridad alta sin oportunidad | Cola de prospectos abiertos actual, sin limitar por fecha de detección; conserva país, servicio, fuente y responsable. |
| Publicaciones por cerrar | Abiertas, no cerradas y con plazo entre ahora y siete días; conserva filtros comerciales. |
| Pipeline y valor abierto | Estado actual, todas las fechas, monedas separadas y filtros comerciales. |
| Seguimientos | Pendientes actuales, por responsable. País, servicio y fuente no se aplican a actividades; se informa en la interfaz. |

**Prioridad:** el contador de Claude `high_priority_without_opportunity` incluye tanto resultados estimados como confirmados. No debe presentarse como “listo para convertir” sin comprobar las condiciones existentes. La clasificación comercial alta no equivale a intención alta. Antes de implementar la separación se contrastarán los criterios con `priority_pending_reasons`, verificación, puntuación completa, análisis pendientes y duplicados; un caso ambiguo conservará la etiqueta de estimado. Se reutilizará una única definición para tarjetas, listas y fichas, sin introducir aprobación nueva ni recalcular scoring en la vista.

Los enlaces de las colas mantendrán los filtros admitidos por cada destino. El filtro `verification`/`priority` de Claude en prospectos se conservará; no se sustituirá por un filtro limitado a los 200 registros ya cargados.

## Validación preparada

El runner visual detecta la ruta real y los permisos de Agent Control y lo agrega a la matriz de capturas cuando exista. Si falta, informa explícitamente que la validación integrada está pendiente. Tras actualizar con main integrado se ejecutará con `ARM_INTEGRATION_REQUIRED=1`; así fallará si falta el módulo o su autorización para el usuario de pruebas.

Matriz: dashboard, Agent Control, prospectos, ficha, empresas, actividades y pipeline a 320, 375, 390, 768, 1366, 1440 y 1920 px; menú móvil, Escape, filtros y orden. Deben comprobarse desbordamiento general, límites de los filtros y accesibilidad de los botones. No se usan datos de producción para las capturas.

Se ejecutarán Rails, RuboCop, Brakeman, bundler-audit, Tailwind y navegador. Las pruebas nuevas cubrirán colas con filtros comerciales y fechas distintas, separación de prioridad estimada/confirmada, enlaces autorizados de Agent Control, roles sin permiso y compatibilidad de acciones existentes.

## Pendientes reales

1. Incorporación autorizada del PR #7 en main, fuera del alcance autorizado a Codex en esta orden.
2. Actualizar la rama de PR #8 contra ese main y resolver archivos compartidos.
3. Unificar métricas, integrar Agent Control y adaptar filtros sin pérdida funcional.
4. Ejecutar toda la matriz, inspeccionar nuevas capturas y adjuntar resultados del commit integrado.

Las 108 pruebas y las 43 capturas de la entrega anterior corresponden al frontend aislado: no se presentan como evidencia de integración con el PR #7. No se afirma CI integrado verde hasta completar los pasos anteriores.
