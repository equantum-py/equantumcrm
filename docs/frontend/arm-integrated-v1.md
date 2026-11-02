# eQuantum ARM · Frontend V1 integrado

Base incorporada: `origin/main` en `f713c8312112f558062dd9061894e38c693ccfa2`, con PR #7. Misma rama `frontend/arm-premium-v1`, PR #8 en borrador. Sin despliegue ni fusión del PR #8.

## Conflictos y presentación

La combinación produjo conflictos de contenido en `views/dashboard/show.html.erb` y `views/layouts/application.html.erb`. Se resolvieron conservando tarjetas, gráficos, colores, responsive, navegación por teclado y estructura premium; incorporando los grupos Prospect AI/Relationship Hub y el acceso autorizado a Agent Control del backend. El layout de autenticación no tuvo conflicto de Git; se conservó identidad y se agregó la descripción ARM.

El dashboard añade colas de sin verificar, análisis por aprobar, alta confirmada, alta estimada y cierres a siete días, con captación por canal. Las colas actuales no usan el período de detección y sí los filtros comerciales; los gráficos y captación utilizan el período. Pipeline conserva sus monedas y su semántica actual. No se agrega un tercer contador redundante del total de altas sin oportunidad.

## Fuente única de datos

Se retira `ArmDashboardHelper`. `DashboardMetrics` conserva sin cambios sus métodos comerciales de Claude y recibe lecturas de presentación adicionales para verificados, oportunidades abiertas, distribución, serie diaria y vistas previas. Reutilizan los scopes ya definidos en el servicio; no hay SQL, agregaciones ni reglas de aprobación en el dashboard o sus helpers. La serie conserva America/Asuncion y un máximo de 60 intervalos.

Confirmación y estimación usan `Lead.priority_confirmed` y el contrato `high_priority_confirmed`/`high_priority_estimated`. Los listados y Kanban reciben identificadores de confirmación en lote para mostrar badges consistentes, sin consultas por fila. Los filtros del servidor `verification`, `priority` y `priority_status` se conservan en prospectos y enlaces. Solo el orden de los registros cargados es local. Los selectores y fechas envían sus filtros con Stimulus: se eliminan los handlers `onchange` inline que la CSP vigente bloqueaba, sin relajar esa política.

La exclusión de sintéticos de captación, series, distribuciones y oportunidades reutiliza `Lead.real` y la exclusión de oportunidades del servicio. Las etiquetas de registros de prueba en ficha/listado utilizan `Lead.test_data`, incluyendo registros con `synthetic: true` sin prefijo.

## Agent Control

Se mantiene el controlador, política, modelos y estados de Claude. Solo cambia la presentación: indicadores premium, tarjetas de agentes y tablas adaptadas a mobile. “Habilitados” describe el interruptor de permiso; no equivale a un agente autónomo o programado. No hay acciones nuevas que activen agentes o ejecuciones. Se conservan acciones permitidas, límites, última ejecución, origen, fuente, resultados, errores y pendientes.

## Límite coordinado con Claude

La exclusión de sintéticos de métricas de actividades y pendientes de Agent Control sigue siendo responsabilidad de la corrección independiente de Claude. No se agregan filtros temporales en vistas/helpers/controladores para ocultarlos. Las lecturas nuevas de actividades conservan la semántica vigente (pendientes, por responsable). No se afirma exclusión global de datos de prueba ni aprobación final de esos indicadores antes de incorporar la corrección correspondiente.

## Validación

La suite conserva las pruebas de backend. Dos aserciones de presentación de `DashboardCaptureTest` se adaptan al título premium y a la tarjeta separada de estimadas, manteniendo las comprobaciones de datos. Se agregan regresiones de integración para scopes reales, filtros/enlaces y acceso por roles a Agent Control, comprobando que una lectura no modifica configuración de agentes.

El workflow visual exige `ARM_INTEGRATION_REQUIRED=1`. Incluye siete pantallas y siete anchos (320, 375, 390, 768, 1366, 1440 y 1920), navegación, foco, filtros del servidor, teclado Kanban, portapapeles, estados vacíos y movimiento reducido. Los fixtures viven solo en una base de test; el historial de laboratorio se inserta sin ejecutar agentes. Son 49 combinaciones y 52 capturas contando menú y estados vacíos. Los resultados y capturas del commit validado quedan en el PR #8.

## Archivos propios de esta integración

- Dashboard: servicio, vista y parcial de colas; eliminación del helper duplicado.
- Navegación y login: layouts de aplicación y autenticación.
- Agent Control: vista y estilos, sin cambios de controlador/política.
- Prospectos y pipeline: anotaciones de presentación en controladores, vistas y filtros compartidos; simplificación del controlador Stimulus de ordenamiento.
- Pruebas: regresiones de integración, aserciones de presentación, runner y workflow visual.

Los modelos, migraciones, configuración de agentes y actualizaciones de dependencias se heredan íntegros de main. No se reimplementa ni se modifica la corrección que prepara Claude.
