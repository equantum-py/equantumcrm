# 09 — Procedimiento de captura rápida

Para publicaciones encontradas manualmente (Facebook, LinkedIn, plataformas freelance, búsqueda web). Objetivo: menos de 2 minutos por publicación.

## Con el CRM solamente
1. Copiar el enlace de la publicación y el párrafo que muestra la intención.
2. CRM → **Captura rápida**: pegar enlace y extracto, elegir fuente, país (solo si es explícito), fecha visible y servicios.
3. Al guardar, el CRM normaliza el enlace (sin `m.`, `www.`, parámetros de seguimiento) y si ya existe te lleva al registro existente (**duplicados**).
4. En la ficha: **Fuente verificada** → **Puntuar** (8 criterios, verificado/inferido) → el CRM suma y asigna la banda → **Calificar** → **Convertir en oportunidad**.

## Con Claude + el CRM (recomendado)
1. Pegar enlace + extracto en Claude con las Skills `eq-facebook-research` y `eq-lead-qualifier`.
2. Claude devuelve: servicio, intención, criterios con justificación, acción recomendada y mensaje sugerido (`eq-sales-copywriter`) en un bloque JSON.
3. En **Captura rápida**, pegar ese bloque en "Análisis de Claude". Queda **pendiente de revisión**.
4. En la ficha, **Aceptar** copia los criterios, servicios, país y mensaje; Rails recalcula la puntuación. **Rechazar** lo descarta sin tocar el prospecto.

Los 6 pasos pedidos quedan cubiertos: servicio, intención, puntuación, duplicados, mensaje y registro. Ningún mensaje se envía desde el CRM.

## Próximo paso (Fase 03)
El servicio Prospect AI (FastAPI) hará el paso 2 automáticamente al guardar, usando el mismo formato JSON, sin que la persona tenga que pasar por Claude.
