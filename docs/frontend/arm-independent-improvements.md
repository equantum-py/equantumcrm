# PR #8 · Mejoras independientes de frontend

> Documento histórico de la preparación/base aprobada. Para el resultado sobre main con PR #7 incorporado, ver [Frontend V1 integrado](arm-integrated-v1.md).


## Alcance

Se conserva la rama `frontend/arm-premium-v1` y el diseño aprobado. No se modifican `dashboard/show.html.erb`, `layouts/application.html.erb` ni `layouts/auth.html.erb`. No se cambian backend, scoring, permisos, rutas o dependencias. Agent Control y el dashboard integrado siguen pendientes de PR #7 en main.

## Mejoras

- Menú móvil: el contenido de fondo queda `inert` durante la apertura, con restauración del estado previo al cerrar o desconectar. Tab y Shift+Tab permanecen dentro del diálogo. Al volver a desktop se liberan el fondo y el scroll; el foco se traslada a la sección activa en lugar del botón móvil oculto.
- Portapapeles: se captura el botón antes de `await` para evitar perder `event.currentTarget`; hay confirmación accesible y salida clara si el navegador rechaza la copia. Los mensajes usan una región de estado y no bloquean al usuario.
- Tablas: el orden utiliza un comparador de títulos reutilizable y un DocumentFragment para insertar las filas en conjunto. El contador de resultados tiene una región de estado permanente desde el HTML.
- Responsive: controles mobile de 16 px para evitar zoom al enfocar, objetivos de 44 px y estados vacíos adaptables con texto y acción. Se respeta el modo de contraste forzado.
- Carga: se estilizan exclusivamente la barra y los estados `aria-busy` nativos de Turbo; no se inventan estados ni se reemplazan datos por skeletons ficticios. La barra respeta movimiento reducido.

## Regresiones verificables en navegador

La matriz existente mantiene los siete anchos y seis pantallas. Se añaden comprobaciones de botones dentro del viewport, Tab/Shift+Tab, fondo inerte y su restauración, retorno de foco, cambio mobile/desktop, copia asíncrona exitosa y rechazada mediante respuestas controladas del API del navegador, desplazamiento Kanban con teclado, estados vacíos y movimiento reducido. Se guardan dos capturas adicionales de estado vacío (390 y 1440 px); sin Agent Control son 45 capturas en total.

Las capturas comprueban geometría y comportamiento; no se afirma comparación automática píxel a píxel contra una referencia aprobada. Se inspeccionan visualmente antes de cerrar la entrega.

## Controles

Rails, RuboCop, Brakeman, Tailwind y el workflow funcional de navegador siguen siendo obligatorios. `bundler-audit` conserva los avisos de las dependencias del main anterior a PR #7; no se silencia ni se actualiza por separado el lockfile. Los resultados vigentes quedan en la descripción y checks del PR #8.
