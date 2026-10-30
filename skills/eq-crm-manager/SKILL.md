---
name: eq-crm-manager
description: Registra y actualiza información comercial en eQuantum CRM (prospectos, empresas, contactos, oportunidades, actividades, seguimientos e historial) respetando permisos, validaciones y deduplicación. Usar cuando se pida cargar, actualizar, mover de etapa o consultar registros del CRM, o preparar la lista de seguimientos del día.
---

# eq-crm-manager

## Cómo se conecta
- Si el CRM está desplegado y la sesión tiene un token de API con alcance adecuado, usar `POST /api/v1/lead_ingestions` (ver `docs/04-integracion-prospect-ai.md`) con `Idempotency-Key`.
- Si no hay API disponible (estado actual: el CRM aún no está implementado), entregar los registros en el formato de importación para carga manual y decirlo explícitamente. Nunca afirmar que algo quedó guardado si no hubo respuesta 200/201.

## Reglas
- No crear registros duplicados: buscar primero por URL, dominio o email.
- No cambiar etapas, montos ni propuestas sin pedido explícito del usuario.
- No cargar datos personales innecesarios; respetar `do_not_contact`.
- Los análisis de IA se cargan como propuesta pendiente de revisión, no como dato final.
- Cada acción realizada se informa con el identificador devuelto por el CRM.

## Tareas frecuentes
1. **Cargar leads** desde `eq-lead-hunter`/`eq-lead-qualifier`.
2. **Registrar actividad**: tipo, sujeto, fecha, resultado.
3. **Seguimientos del día**: listar actividades vencidas y de hoy por responsable, con la acción sugerida.
4. **Convertir lead en oportunidad**: solo leads `qualified` y `verified`.
