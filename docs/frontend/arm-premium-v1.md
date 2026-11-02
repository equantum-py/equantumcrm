# eQuantum ARM · Frontend V1

> Documento histórico de la preparación/base aprobada. Para el resultado sobre main con PR #7 incorporado, ver [Frontend V1 integrado](arm-integrated-v1.md).


## Auditoría y decisiones

La base usa Rails 8.1, Tailwind 4, Turbo y Stimulus. Ya existían componentes de encabezado, filtros, badges, estados vacíos, permisos por acción y drag and drop de pipeline. Las principales brechas eran jerarquía visual plana, tablas que requerían desplazamiento en mobile, navegación móvil sin gestión de foco/cierre al navegar y poca claridad sobre períodos de los indicadores.

La implementación mantiene ese stack y todas las acciones. Agrega tokens de color, superficies, formularios y estados compartidos; identidad ARM; seis indicadores principales y los ocho indicadores anteriores complementarios; barras accesibles de captación, fuentes, países y prioridad; foco de oportunidades y seguimientos reales; tarjetas mobile de prospectos y empresas; controles locales de verificación y orden; navegación accesible con Escape, retorno de foco, bloqueo de scroll y limpieza Turbo.

## Alcance y compatibilidad

- No cambia modelos, rutas, migraciones, controladores, políticas, autenticación, scoring, FastAPI ni dependencias del proyecto.
- El helper de dashboard consulta datos existentes sin modificar registros. Respeta filtros existentes y limita a 8 oportunidades y 6 seguimientos; la serie tiene como máximo 60 intervalos.
- Valores monetarios conservan su moneda. No se suman importes de diferentes monedas.
- Las acciones de verificación, aprobación/rechazo de IA, calificación y conversión conservan sus condiciones y permisos.
- El Kanban conserva el controlador original y sus atributos de movimiento. El scroll queda contenido en el tablero; la vista Tabla existente sigue disponible.
- Las propuestas se muestran como **enviadas**, según el cálculo existente: no hay una entidad de propuestas pendientes. No se infieren pendientes.
- No se agregan menús de agentes, notificaciones ni ejecuciones simuladas. Prospect AI sigue en la ficha existente.
- El listado obtiene hasta 200 registros del servidor. Verificación y orden actúan sobre esos registros y lo indican expresamente. Los filtros superiores siguen consultando toda la base.
- La etiqueta DEMO identifica solamente títulos marcados explícitamente con el prefijo [DEMO] o [SINTÉTICO]; no hay un campo de clasificación de datos de prueba en el modelo actual. Se recomienda incorporarlo en una futura tarea de backend y excluirlos explícitamente de métricas. Esta entrega no elimina registros ni altera los cálculos del backend.
- La prioridad alta del dashboard es la clasificación comercial almacenada, distinta de la banda de intención. Puede seguir pendiente de aprobación; las fichas conservan esa distinción.
- Captación/país/fuente/prioridad se filtran por fecha de detección. Pipeline abierto y etapas usan todas las fechas. Actividades usan responsable; los otros filtros comerciales no se aplican a actividades. Cada sección lo explica.

## Validación reproducible

`bin/rails test` ejecuta la suite existente y cinco regresiones nuevas de frontend. `bin/rails tailwindcss:build` compila los estilos. `bin/rubocop` verifica Ruby.

El workflow independiente `ARM frontend visual validation` crea una base PostgreSQL de test, compila Tailwind y ejecuta `RAILS_ENV=test bin/rails runner test/visual/arm_capture.rb`. Genera capturas reales de seis pantallas a 320, 375, 390, 768, 1366, 1440 y 1920 px y del menú móvil. Falla si hay overflow global o falla la navegación. Los archivos quedan en el artefacto `arm-frontend-screenshots`. Los datos sintéticos se crean exclusivamente en test; el script se niega a ejecutarse en otro entorno.

## Coordinación

Rama: `frontend/arm-premium-v1`, basada en main. El PR #6 de Claude agrega una prueba del piloto; no se modifica. Durante la implementación apareció el PR #7 (`claude/project-thread-cgqaab`, `69a09ff`) con Agent Control y evolución ARM. Hay superposición concreta en `views/dashboard/show.html.erb`, `views/layouts/application.html.erb` y `views/layouts/auth.html.erb`; además cambia el contrato de `DashboardMetrics`. Se detiene exclusivamente la integración de esas partes: no se fusiona, no se incorpora su backend ni se reescribe su rama. Ambos PR quedan aislados para una integración coordinada que conserve Agent Control y los cálculos nuevos. No fusionar ni publicar automáticamente.

## Siguiente iteración

Agregar, mediante el trabajo de backend coordinado con Claude, clasificación estructurada de registros sintéticos, propuestas pendientes y metadatos reales de ejecución de agentes. Migrar filtros locales a consultas del servidor cuando exista paginación. Revisar índices de consultas de dashboard si crece el volumen. Mantener el máximo de 60 puntos del gráfico y los límites de listas.

## Resultados de la primera ejecución

Commit `8c3c0f9`: suite Rails **107 pruebas, 413 aserciones, 0 fallos, 0 errores**. RuboCop y Brakeman correctos. Tailwind compila. La prueba visual completó 42 combinaciones sin overflow general y produjo 42 capturas; falló después por buscar el botón por aria-label con la configuración predeterminada de Capybara. Se corrige el selector y se vuelve a validar la navegación.

El job de seguridad falla en `bundler-audit` por dependencias ya presentes en main: Loofah 2.25.2 Nokogiri 1.19.4 y rails-html-sanitizer 1.7.1. El lockfile se conserva íntegro; no se silencian avisos ni se cambian dependencias desde este PR de frontend. Corrección coordinada de dependencias: Loofah >= 2.25.3 Nokogiri >= 1.19.5 y rails-html-sanitizer >= 1.7.2 según la salida del auditor. Ver CRM Actions del PR #8 antes de integrar.
