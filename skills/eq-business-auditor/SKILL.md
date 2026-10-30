---
name: eq-business-auditor
description: Audita la presencia digital pública de un negocio (sitio web, experiencia mobile, SEO técnico, ecommerce, analítica) y prepara un diagnóstico comercial con hallazgos verificables para eQuantum. Usar cuando se pida investigar, auditar o diagnosticar una empresa o sitio web antes de contactarla o de armar una propuesta.
---

# eq-business-auditor

## Principios
- Solo hallazgos comprobables y reproducibles: qué se revisó, con qué herramienta, cuándo, y el resultado.
- Un sitio "antiguo" no prueba que el negocio quiera contratar. El diagnóstico es una hipótesis de oportunidad, no una necesidad declarada.
- Tono de diagnóstico, no de crítica. Nada de exagerar problemas para vender.
- No hacer pruebas intrusivas (escaneo de vulnerabilidades, carga, formularios con datos falsos).

## Checklist
Seguir `references/checklist.md`. Para cada punto: `ok`, `problema`, `no verificado` (con motivo).

## Proceso
1. Confirmar URL y nombre comercial. Abrir el sitio; si no carga, registrarlo y parar.
2. Recorrer el checklist con las herramientas disponibles (lectura de la página, PageSpeed Insights público si la sesión puede consultarlo, inspección de HTML).
3. Priorizar 3 hallazgos con mayor impacto comercial (ventas, contactos, visibilidad).
4. Relacionar cada hallazgo con un servicio del catálogo eQuantum.

## Salida
```markdown
## Diagnóstico — <Nombre comercial> (<URL>) — <fecha>
**Resumen en 2 líneas**
**Hallazgos verificados** (tabla: punto · resultado · evidencia · servicio relacionado)
**No verificado** (y por qué)
**Oportunidades priorizadas** (máx. 3, con impacto esperado en términos cualitativos)
**Siguiente paso sugerido**
```
