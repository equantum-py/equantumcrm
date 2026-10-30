# 06 — Fuentes de oportunidades y evaluación de Facebook

Fecha de verificación: 2026-10-30. Toda afirmación sobre una plataforma está respaldada por la fuente enlazada o marcada como "a confirmar".

## 1. Facebook: opciones evaluadas

| Opción | ¿Viable para eQuantum? | Evidencia / motivo |
|---|---|---|
| Graph API para leer Grupos | **No** | Meta retiró la API de Grupos en abril de 2024 ([aviso de Cloud Campaign](https://www.cloudcampaign.com/blog/important-notice-regarding-metas-deprecation-of-facebook-groups), [Zoho](https://help.zoho.com/portal/fr/community/topic/discontinuing-facebook-groups-due-to-api-deprecation?page=12)) |
| Búsqueda de publicaciones públicas por palabra clave vía Graph API | **No** | No existe un endpoint de búsqueda de publicaciones para apps comerciales |
| Meta Content Library / API | **No** | Solo para instituciones de investigación sin fines de lucro ([requisitos](https://developers.facebook.com/docs/content-library-and-api/get-access)) |
| Scraping (bots, extensiones, servicios de terceros que "extraen" grupos) | **No, descartado** | Prohibido por las condiciones de Meta sobre recolección automatizada; riesgo de bloqueo de la cuenta comercial y legal. Además lo excluye la dirección del proyecto |
| Claude in Chrome navegando con la sesión del usuario | **Parcial, a validar** | No está disponible en esta sesión. Si se instala, sirve para lectura asistida y supervisada (una persona dirige, volumen bajo), no para recorrer grupos en masa ni de forma programada |
| **Captura asistida por humano** | **Sí — recomendada** | Un integrante de eQuantum, miembro legítimo de los grupos, lee como cualquier usuario y registra en el CRM las publicaciones con intención (URL + extracto). Prospect AI y las Skills clasifican y puntúan |
| Página de Facebook propia de eQuantum (Pages API, Messenger, Lead Ads) | **Sí** | Canal entrante oficial: mensajes y formularios que llegan a la página propia se pueden integrar por API con permisos de la app y revisión de Meta |

### Flujo recomendado: captura asistida

1. Dirección define una lista de 10–20 grupos relevantes por país (emprendedores, pymes, ecommerce, Shopify). Un integrante se une con su perfil real y respeta las reglas de cada grupo (muchos prohíben autopromoción).
2. Rutina diaria de 20–30 minutos: búsqueda dentro de cada grupo con términos de `skills/eq-facebook-research/references/terminos-busqueda.md`.
3. Por cada publicación con posible intención: copiar enlace del post + texto → "Captura rápida" del CRM (o pegarlo a Claude con la Skill `eq-facebook-research`, que arma el registro).
4. Prospect AI clasifica y propone puntuación; la persona acepta o ajusta.
5. La respuesta pública o mensaje se redacta con `eq-sales-copywriter` y **lo envía la persona a mano**, respetando las reglas del grupo.

Mejora futura (Fase 04/05): bookmarklet o extensión propia mínima que solo envía al CRM la URL y el texto **que el usuario seleccionó** en la página abierta. No navega ni lee nada por su cuenta.

## 2. Otras fuentes

| Fuente | Mecanismo autorizado | Viabilidad | Notas |
|---|---|---|---|
| LinkedIn | Lectura manual del feed y búsquedas con la cuenta propia; captura asistida igual que Facebook | Media | La API oficial no permite buscar publicaciones de terceros. Scraping prohibido por sus condiciones |
| Google Search | Búsqueda manual o de Claude con herramienta de búsqueda web; consultas tipo `"busco desarrollador" tienda online Paraguay` | Media | La API Custom Search JSON está cerrada a clientes nuevos y se apaga el 1-ene-2027 ([detalle](https://blog.apify.com/google-custom-search-api-alternative/)). Alternativas de pago (Brave Search API u otras) requieren aprobación de gasto |
| Google Maps | Google Places API (oficial) para listar negocios por rubro y zona; luego auditoría del sitio web | Alta para prospección **en frío** | Tiene cuota y costo por uso; cotizar antes de activar. Sitio "antiguo" no implica necesidad de contratar: el lead se marca como hipótesis, no como solicitud |
| Comunidades Shopify | Lectura manual de foros públicos y del directorio de partners | Media | Respetar términos del foro; muchas solicitudes son en inglés |
| Plataformas freelance (Workana, Upwork, Malt en España) | Uso normal como proveedor con cuenta propia; las ofertas son pedidos explícitos | **Alta** | Es la fuente con intención más clara. Requiere perfil de eQuantum y en algunas, costo por propuesta (decisión de Dirección) |
| Licitaciones y compras públicas (DNCP en Paraguay, Mercado Público en Chile, SECOP en Colombia, Plataforma de Contratación en España) | Portales y datos abiertos oficiales | Media–alta | Fuente pública y lícita de demanda de desarrollo web y sistemas. A validar volumen relevante |
| Formulario propio / sitio equantum.com.py | Formulario → API de ingesta | Alta | Canal entrante; integrable en Fase 03 |

## 3. Reglas que aplican a todas las fuentes

- Solo contenido accesible legítimamente para la cuenta que lo lee; no se eluden CAPTCHA, bloqueos ni privacidad de grupos.
- Volumen humano, sin recorridos automáticos de perfiles.
- Se guarda el mínimo dato personal necesario (ver `02-modelo-de-datos.md` §6).
- Una oportunidad es "verificada" solo si alguien abrió la fuente y confirmó texto y fecha.
- Ningún mensaje sale sin aprobación de una persona.
