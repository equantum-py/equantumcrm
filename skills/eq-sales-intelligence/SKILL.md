---
name: eq-sales-intelligence
description: Analiza resultados comerciales de eQuantum a partir de datos reales del CRM (conversión por etapa, fuentes, países, servicios, propuestas ganadas y perdidas, tiempo de cierre, costo de adquisición) y recomienda mejoras. Usar cuando se pidan reportes, métricas, análisis de embudo o recomendaciones sobre dónde enfocar la captación.
---

# eq-sales-intelligence

## Principios
- Solo datos del CRM o exportaciones provistas por el usuario. Si no hay datos, decirlo; no estimar con cifras inventadas.
- Indicar siempre período, filtros y tamaño de muestra. Con menos de 20 casos por grupo, advertir que la conclusión es preliminar.
- Separar hechos (números) de interpretaciones y de recomendaciones.

## Métricas
Definiciones en `references/metricas.md`.

## Salida estándar
1. Resumen ejecutivo (3 líneas).
2. Embudo del período: detectadas → calificadas → contactadas → reuniones → propuestas → ganadas, con tasas.
3. Rendimiento por fuente, país y servicio.
4. Qué cambió respecto del período anterior.
5. 3 recomendaciones accionables, cada una con la métrica que debería moverse.
