---
name: eq-facebook-research
description: Investigación comercial en Facebook y grupos de Facebook para eQuantum mediante captura asistida por una persona, sin scraping ni automatización prohibida. Usar cuando el usuario pegue publicaciones o enlaces de Facebook, pida identificar grupos relevantes, términos de búsqueda por país, o quiera convertir una publicación de Facebook en un lead verificable para el CRM.
---

# eq-facebook-research

## Lo que esta Skill puede y no puede hacer
- No existe API oficial para leer grupos (retirada por Meta en 2024) y la Meta Content Library no admite uso comercial. Ver `docs/06-fuentes-y-facebook.md`.
- Claude no navega Facebook por su cuenta. Trabaja con lo que la persona pega (URL + texto) o, si la sesión tiene Claude in Chrome, con la página que la persona tenga abierta y le pida leer, una por vez.
- Nunca: recorrer grupos o perfiles en masa, unirse a grupos, publicar, comentar ni enviar mensajes.

## Tareas

### A. Proponer grupos y términos
1. Para el país pedido, sugerir tipos de grupo (emprendedores, pymes, ecommerce, Shopify, comercio local) y cómo verificar relevancia: actividad reciente, reglas que permitan responder solicitudes, tamaño.
2. Entregar términos de búsqueda desde `references/terminos-busqueda.md`, adaptados al país.
3. No afirmar que un grupo existe o es público sin que la persona lo haya confirmado.

### B. Convertir publicaciones en leads
Para cada publicación que la persona aporte:
1. Verificar que hay intención de contratar (no es una oferta, no es una pregunta teórica). Si es dudoso, decirlo.
2. Extraer: URL, fecha visible, país (solo si está explícito o hay señal fuerte; marcar `inferred`), servicio, urgencia, presupuesto literal, canal legítimo de contacto (responder en el hilo, mensaje si la publicación lo invita).
3. Registrar evidencia: extracto mínimo literal. No copiar comentarios de terceros ni datos personales innecesarios.
4. Marcar `verification_status: verified` solo si la persona confirma que la URL abre y la fecha corresponde.
5. Entregar el bloque en el formato de `eq-lead-hunter` con `source: facebook_group` o `facebook` y pasarlo a `eq-lead-qualifier`.

### C. Reglas del grupo
Recordar a la persona revisar si el grupo permite responder con ofertas. Si no lo permite, la acción recomendada es no contactar o solo aportar valor sin vender.
