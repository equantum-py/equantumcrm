# PR #8 · Revisión de Dirección e integración pendiente

> Documento histórico de la preparación/base aprobada. Para el resultado sobre main con PR #7 incorporado, ver [Frontend V1 integrado](arm-integrated-v1.md).


Estado comprobado el 02/11/2026 mediante GitHub:

- PR #8 aprobado con observaciones; permanece en borrador, sin autorización de fusión ni despliegue.
- `main`: `9b5cc98dee0a588c6c913e4cb8ca445359329524`.
- PR #7: abierto, sin fusionar; cabeza corregida `db31ab4240b3304f005864918c8e08368c9e24db`.
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

**Prioridad:** el contrato corregido ofrece `DashboardMetrics#high_priority_confirmed` y `#high_priority_estimated`, respaldados por `Lead.priority_confirmed` y `Lead.priority_estimated`. Se consumirán directamente. El contador `high_priority_without_opportunity` es el total de ambos y no se mostrará como una tercera tarjeta ni como “listos para convertir”. No se copiarán las condiciones de aprobación, análisis pendientes o duplicados a helpers o vistas. La banda de intención se mantendrá separada de la prioridad comercial.

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


## Contrato corregido verificado · db31ab4

El PR #7 continúa abierto y main sigue en `9b5cc98`. Su workflow CRM `41500182649` está en verde. La integración y sus capturas todavía no se ejecutaron en PR #8.

| Necesidad visual | Fuente canónica comprobada | Semántica |
|---|---|---|
| Sin verificar | `DashboardMetrics#to_verify` | Prospectos reales abiertos; filtros comerciales; sin fechas de captación. |
| Análisis por aprobar | `#pending_ai_reviews` | Cantidad de análisis pendientes de prospectos reales abiertos; no equivale a cantidad de prospectos distintos. |
| Alta confirmada sin oportunidad | `#high_priority_confirmed` | Clasificación confirmada mediante el scope del modelo; sin fechas de captación. |
| Alta estimada sin oportunidad | `#high_priority_estimated` | Estimada según el mismo contrato, sin cálculo paralelo. |
| Total alto sin oportunidad | `#high_priority_without_opportunity` | Referencia de consistencia: confirmadas + estimadas. Evitar tarjeta redundante. |
| Cierran en siete días | `#closing_soon_count`, `#closing_soon` | Prospectos reales abiertos, publicación no cerrada y plazo dentro de siete días desde ahora. |
| Captación por canal | `#leads_by_channel` | Período de detección y filtros comerciales. Etiquetar API como API; no inferir agentes autónomos. |
| Exclusión de registros de prueba | `Lead.real`, `Lead.test_data` | Columna `synthetic` y compatibilidad con prefijos [DEMO]/[SINTÉTICO], resueltas por el modelo. |
| Pipeline, valor y cierres | Métodos existentes de `DashboardMetrics` | El servicio ya excluye oportunidades vinculadas a prospectos de prueba. Mantener monedas separadas. |
| Permiso de Agent Control | `policy(:agent_control).show?` | Mostrar la ruta real únicamente con permiso; conservar autorización del servidor. |

### Adaptaciones que requieren la integración

1. Retirar las consultas de `ArmDashboardHelper` y las agregaciones comerciales de la vista. No basta con cambiar etiquetas: `Lead.filter` y `Opportunity.filter` actuales no aplican por sí solos la exclusión canónica de sintéticos.
2. El servicio corregido no expone todavía métodos públicos para la serie diaria, prospectos verificados, distribución completa de prioridades ni vistas previas de oportunidades/seguimientos usadas por el frontend. Completar esas lecturas dentro de la única fuente `DashboardMetrics`, reutilizando sus scopes; no acceder a métodos privados mediante `send` ni conservar cálculos de respaldo en helpers.
3. Conservar filtros del servidor `verification`, `priority` y `priority_status`; los enlaces de confirmadas/estimadas pasarán los valores `confirmed`/`estimated`. No confundirlos con el filtro local de los registros cargados.
4. En listados y fichas, identificar sintéticos con el contrato del modelo, incluyendo el caso `synthetic: true` sin prefijo. No continuar únicamente con la expresión regular de títulos del frontend anterior.
5. Verificar por separado actividades y Agent Control: los scopes de actividades y las consultas de pendientes de Agent Control revisadas no usan `Lead.real`. No afirmar exclusión global a partir de los contadores de captación. Las pruebas deben cubrir actividades/análisis vinculados a prospectos y oportunidades de prueba; cualquier corrección de lectura se centralizará en la capa de datos correspondiente y se documentará, sin heurísticas nuevas en la vista.

### Casos de aceptación preparados

- Un prospecto `synthetic: true` con título normal y otro con prefijo heredado quedan fuera de tarjetas, series y listas comerciales, junto con sus oportunidades asociadas.
- La confirmada y la estimada consumen los scopes del modelo; la suma coincide con el total sin duplicar la tarjeta. Cambiar verificación, puntuación, análisis pendiente o duplicados no deja una etiqueta confirmada desactualizada.
- Un prospecto anterior al período permanece en las colas actuales, pero no en captación del período. País, servicio, fuente y responsable se conservan donde correspondan.
- Registros con varias propuestas de análisis no se presentan como prospectos distintos; cierres fuera de siete días o publicaciones cerradas no entran en la cola.
- Usuarios sin `agents.read` no ven el acceso a Agent Control y siguen recibiendo la denegación del servidor al intentar la ruta.
- No se muestran agentes diseñados como operativos ni se deduce programación a partir del interruptor habilitado.
- El workflow integrado se ejecutará con `ARM_INTEGRATION_REQUIRED=1` y deberá producir capturas nuevas incluyendo Agent Control, además de Rails, RuboCop, Brakeman, bundler-audit y Tailwind en verde.

No se modifican los tres archivos compartidos ni se incorpora la rama del PR #7 antes de que su integración en main esté completada.
