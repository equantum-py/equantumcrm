# 03 — Diseño funcional del CRM

Estado: **diseño**. Ninguna pantalla está implementada.

## 1. Navegación

Barra lateral fija (colapsable en mobile a menú inferior de 5 ítems + "Más"):

```
eQuantum CRM
├── Inicio (Dashboard)
├── Prospect AI        ← bandeja de oportunidades detectadas
├── Prospectos (Leads)
├── Pipeline           ← Kanban / Tabla
├── Empresas
├── Contactos
├── Actividades        ← "Mis pendientes" por defecto
├── Propuestas
├── Reportes
└── Administración     ← solo admin/manager
Barra superior: búsqueda global (⌘K / Ctrl+K) · "+ Nuevo" (lead, empresa, actividad) · usuario
```

Tareas frecuentes en ≤ 3 pasos:

| Tarea | Pasos |
|---|---|
| Registrar una oportunidad vista en Facebook | "+ Nuevo" → Captura rápida (pegar URL + texto) → Guardar |
| Calificar un lead | Abrir lead → revisar criterios propuestos → Aceptar/ajustar |
| Mover un negocio de etapa | Arrastrar en Kanban (o selector en la ficha) |
| Registrar un seguimiento | Ficha → "Actividad" → tipo + fecha → Guardar |

## 2. Sistema de componentes (Tailwind + ViewComponent o partials)

- **Layout**: `AppShell` (sidebar + topbar + contenido), `PageHeader` (título, acciones primarias, migas).
- **Datos**: `DataTable` (orden, filtros persistidos en URL, paginación, selección múltiple), `FilterBar`, `EmptyState` (con acción real, nunca datos de ejemplo), `KpiStat`.
- **Estados**: `StatusBadge` (colores fijos por estado), `ScoreBadge` (banda muy alta/alta/media/baja + número), `VerificationBadge` (verificado / sin verificar / inaccesible).
- **Formularios**: `FormField` con error en línea, `ComboBox` (catálogos), `MoneyInput` (moneda por país).
- **Pipeline**: `KanbanBoard` (Turbo Streams + Stimulus `sortable`), `StageColumn`, `DealCard` (nombre, empresa, valor, responsable, días en etapa).
- **Feedback**: flash con Turbo, confirmaciones solo en acciones destructivas.

Estilo: fondo claro (`slate-50`), superficies blancas con borde sutil, un color de marca para acción primaria, tipografía Inter o del sistema, densidad media en tablas. Sin gradientes ni animaciones decorativas. Contraste AA.

## 3. Módulos

### 3.1 Dashboard ejecutivo
KPIs calculados con consultas reales (si no hay datos, se muestra 0 y un estado vacío, nunca cifras de ejemplo): oportunidades detectadas, prospectos calificados, contactos pendientes, conversaciones iniciadas, reuniones, propuestas enviadas, negociaciones, ganados, perdidos, valor del pipeline (por moneda, sin convertir salvo que se apruebe un tipo de cambio), conversión por etapa.
Filtros: rango de fechas, país, servicio, fuente, responsable. Los filtros viajan en la URL para compartir vistas.

### 3.2 Prospect AI (bandeja)
Lista de leads con `created_via ∈ {api, skill}` o pendientes de calificar. Columnas: plataforma, extracto, enlace original (abre en pestaña nueva), fecha publicada (o "sin fecha verificada"), país, servicio, puntuación, verificación, recomendación.
Ficha: evidencia, desglose de puntuación criterio por criterio con justificación y marca **Verificado / Inferido**, análisis de IA pendiente con botones Aceptar / Rechazar / Editar, mensaje sugerido (copiar, nunca "enviar").
Acciones: Verificar fuente, Descartar (con motivo), Convertir en oportunidad.

### 3.3 Prospectos
CRUD completo, vista tabla, historial (actividades + auditoría), detección de posibles duplicados al guardar.

### 3.4 Empresas y 3.5 Contactos
CRUD, ficha con oportunidades, actividades y servicios de interés. Contactos: campos mínimos, base legal, "no contactar". Acceso: el rol `sales` ve sus registros y los no asignados; `manager`/`admin` ven todo.

### 3.6 Pipeline
Kanban y tabla sobre la misma consulta. Etapas configurables en Administración (nombre, orden, probabilidad, tipo). Cambiar de etapa registra actividad y auditoría. Perdido exige motivo.

### 3.7 Actividades
Tipos: llamada, reunión, tarea, seguimiento, recordatorio, nota interna. Vista "Mis pendientes" (vencidas, hoy, próximas). Recordatorios por job (correo interno o notificación en app; sin mensajes a clientes).

### 3.8 Propuestas
Editor con ítems tomados de `service_rates` (rango autorizado visible). Flujo: borrador → revisión → aprobada → enviada (marcada manualmente; el CRM no envía correos a clientes en esta etapa) → aceptada/rechazada/vencida. PDF en Fase 05, solo cuando esté probado.

### 3.9 Reportes
Por canal, país, servicio; conversión por etapa; propuestas ganadas/perdidas; actividad por usuario; tiempo promedio de cierre. Exportación CSV auditada.

### 3.10 Administración
Usuarios, roles y permisos; servicios; países; etapas; criterios de puntuación (versión nueva, nunca edición destructiva de la vigente); tarifas; integraciones y clientes API (crear/revocar token, se muestra una sola vez); registro de auditoría con filtros.

## 4. Matriz de permisos inicial

| Permiso | admin | manager | sales | analyst | viewer |
|---|:-:|:-:|:-:|:-:|:-:|
| Ver dashboard/reportes | ✓ | ✓ | propios | ✓ | ✓ |
| Crear/editar leads, empresas, contactos | ✓ | ✓ | ✓ | ✓ | — |
| Aceptar análisis de IA | ✓ | ✓ | ✓ | ✓ | — |
| Mover pipeline / editar oportunidades | ✓ | ✓ | propias | — | — |
| Crear propuestas | ✓ | ✓ | ✓ | — | — |
| Aprobar propuestas / precios fuera de rango | ✓ | ✓ | — | — | — |
| Exportar CSV | ✓ | ✓ | — | ✓ | — |
| Administración y auditoría | ✓ | lectura | — | — | — |

## 5. Criterios de aceptación por módulo

Un módulo se acepta solo si tiene: persistencia real, validaciones de modelo, política de autorización con prueba, manejo de errores visible, pruebas (modelo + request + al menos un system test del flujo principal), documentación breve y evidencia (captura o grabación) adjunta al PR.
