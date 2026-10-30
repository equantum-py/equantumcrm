# 05 — Skills de Claude

Las 8 Skills están en `skills/`. Cumplen el formato oficial verificado (ver `00-diagnostico.md` §4) y se validan en CI con `scripts/validate_skills.py`.

## Qué es y qué no es una Skill

Una Skill es un paquete de instrucciones y recursos que Claude carga cuando la tarea coincide con su `description`. **No** es un proceso que corra solo, no tiene horario y no guarda estado. Lo periódico (revisar fuentes, recordatorios, reportes) va en jobs de Rails o en Prospect AI.

## Mapa

| Skill | Rol | Entrada | Salida | Pasa a |
|---|---|---|---|---|
| eq-lead-hunter | Buscar oportunidades en fuentes autorizadas | Mercado, servicio, ventana | Hallazgos YAML verificados | eq-lead-qualifier |
| eq-facebook-research | Captura asistida de Facebook | URL + texto pegados por la persona | Hallazgos YAML | eq-lead-qualifier |
| eq-lead-qualifier | Puntuar con rúbrica 100, deduplicar | Hallazgos | Desglose por criterio, banda | eq-crm-manager |
| eq-business-auditor | Diagnóstico de presencia digital | URL del negocio | Informe con hallazgos verificables | eq-sales-copywriter / eq-proposal-builder |
| eq-sales-copywriter | Borradores de mensajes por país | Lead o diagnóstico | 2 variantes + seguimientos | (persona aprueba y envía) |
| eq-proposal-builder | Propuestas con tarifas autorizadas | Oportunidad + tarifas | Propuesta en plantilla + pendientes | eq-crm-manager |
| eq-crm-manager | Registrar y actualizar el CRM | Registros | Confirmación con IDs o lote para carga manual | — |
| eq-sales-intelligence | Analizar resultados | Datos del CRM | Reporte + 3 recomendaciones | Dirección |

## Instalación

- **Claude Code (este repo)**: `mkdir -p .claude/skills && cp -r skills/eq-* .claude/skills/` (o enlace simbólico). Quedan disponibles al abrir Claude Code en el repo.
- **claude.ai**: comprimir cada carpeta (`cd skills && zip -r eq-lead-hunter.zip eq-lead-hunter`) y subirla en Configuración → Funciones (requiere plan con ejecución de código).
- **API**: subir por el endpoint de skills; nota: en la API las Skills no tienen acceso a red, así que eq-lead-hunter no puede buscar allí.

Las Skills no se sincronizan entre superficies: hay que instalarlas en cada una.

## Estado

Diseñadas y escritas (v1). Todavía no se probaron en uso real; la prueba de captación (`07-prueba-de-captacion.md`) es su primera validación.
