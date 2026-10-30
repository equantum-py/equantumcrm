---
name: eq-lead-hunter
description: Busca oportunidades comerciales públicas para eQuantum Consulting (web, ecommerce, Shopify, SEO, Ads, apps, automatización, consultoría) en fuentes autorizadas como búsqueda web, plataformas freelance, licitaciones y comunidades públicas, y entrega cada hallazgo con enlace verificable. Usar cuando se pida buscar clientes, prospectos, leads u oportunidades de contratación en Paraguay, Chile, Colombia o España.
---

# eq-lead-hunter

Encontrar solicitudes reales de servicios digitales y entregarlas listas para calificar. Calidad antes que cantidad.

## Reglas no negociables
- Solo fuentes accesibles legítimamente con las herramientas disponibles en la sesión. Si una fuente requiere sesión iniciada (Facebook, LinkedIn) y no hay herramienta de navegador con sesión del usuario, decirlo y derivar a `eq-facebook-research` (captura asistida).
- No hacer scraping, no eludir CAPTCHA ni bloqueos, no recorrer perfiles.
- No inventar oportunidades, fechas, presupuestos ni países. Lo que no se ve en la fuente queda vacío.
- Abrir cada enlace antes de reportarlo. Si no se pudo abrir: `verification_status: unreachable` y no cuenta como verificada.

## Proceso
1. Confirmar con el usuario mercado(s), servicio(s) y ventana de tiempo (por defecto: últimos 30 días).
2. Elegir fuentes según `docs/06-fuentes-y-facebook.md` (orden sugerido: plataformas freelance → búsqueda web con frases de intención → licitaciones públicas → comunidades Shopify).
3. Buscar con frases de intención por país (ver `../eq-facebook-research/references/terminos-busqueda.md`), no solo coincidencias exactas.
4. Por cada candidato: abrir la fuente, confirmar que es una solicitud (no una oferta de servicios ni spam), registrar fecha visible.
5. Descartar: ofertas de agencias o freelancers, publicaciones de más de 90 días (salvo que el usuario lo pida y quede marcado), solicitudes fuera de los servicios de eQuantum.
6. Entregar la tabla de salida y pasar los hallazgos a `eq-lead-qualifier`.

## Formato de salida (un bloque por hallazgo)
```yaml
source: freelance_platform        # clave de catálogo de sources
original_url: https://...
published_at: 2026-10-28          # null si no se ve
published_at_verified: true
country_hint: CL                  # null si no se puede afirmar
service_keys: [shopify]
text_excerpt: "cita literal mínima que prueba la intención"
contact_channel: "responder en la plataforma"
published_budget_text: null       # literal o null
verification_status: verified     # verified | unreachable
notes: "por qué es relevante"
```
Al final: cuántas fuentes se revisaron, cuántos candidatos se descartaron y por qué, y limitaciones encontradas.
