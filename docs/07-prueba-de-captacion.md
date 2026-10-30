# 07 — Prueba controlada de captación (preparación)

Estado: **preparada, no ejecutada**. Se ejecuta en una sesión dedicada (Fase 04, o antes si Dirección lo pide), sin depender de que el CRM esté construido.

## Objetivo
Encontrar **10 oportunidades reales y verificables** en PY, CL, CO y ES. Si no se llega a 10, informar cuántas y por qué.

## Definición de "verificada"
1. La fuente se abrió y existe.
2. El texto muestra intención de contratar un servicio del catálogo.
3. La fecha de publicación es visible y está dentro de los últimos 30 días (se informa la fecha exacta).
4. Hay una vía legítima de contacto.

## Fuentes y responsables

| Fuente | Quién la ejecuta | Herramienta | Meta |
|---|---|---|---|
| Plataformas freelance (Workana, Upwork, Malt) | Claude con búsqueda web en páginas públicas; la persona confirma si requiere login | eq-lead-hunter | 4 |
| Búsqueda web con frases de intención | Claude | eq-lead-hunter | 2 |
| Grupos de Facebook | **La persona** (captura asistida, 30 min/día × 3 días) | eq-facebook-research | 3 |
| LinkedIn | La persona (captura asistida) | eq-facebook-research (mismo flujo) | 1 |
| Licitaciones públicas | Claude | eq-lead-hunter | bonus |

## Procedimiento
1. Día 0: Dirección confirma grupos de Facebook y cuentas a usar.
2. Días 1–3: búsqueda y captura. Cada hallazgo en el formato YAML de eq-lead-hunter.
3. Calificación con eq-lead-qualifier (rúbrica v1).
4. Para los 5 mejores: diagnóstico breve (eq-business-auditor, si tienen sitio) y mensaje sugerido (eq-sales-copywriter).
5. Entrega: tabla con los 10 campos pedidos (plataforma, enlace, fecha, país, servicio, evidencia, puntuación, justificación, acción recomendada, mensaje sugerido) + registro de descartes + limitaciones.
6. **No se contacta a nadie** durante la prueba sin aprobación de Dirección por cada mensaje.

## Métricas de la prueba
Fuentes revisadas, candidatos vistos, descartados (por motivo), verificados, puntuación media, horas invertidas por fuente. Esto define qué fuentes automatizar primero.
