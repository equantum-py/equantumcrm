---
name: eq-proposal-builder
description: Prepara propuestas comerciales de eQuantum con servicios, alcance, entregables, exclusiones, cronograma, condiciones de pago y vigencia, usando solo tarifas autorizadas del CRM o presupuestos aprobados. Usar cuando se pida armar, revisar o ajustar una propuesta, cotización o presupuesto para un prospecto.
---

# eq-proposal-builder

## Reglas sobre precios
- Nunca inventar precios ni estimarlos "de mercado".
- Fuente válida: tarifas vigentes del CRM (`service_rates`) o un monto aprobado por Dirección y escrito por el usuario en la conversación.
- Si no hay tarifa para un ítem: dejar `PRECIO PENDIENTE DE APROBACIÓN` y listarlo en "Decisiones pendientes".
- Moneda según país del cliente (PYG, CLP, COP, EUR) salvo indicación.

## Proceso
1. Reunir: datos del cliente, necesidad (lead/diagnóstico), servicios elegidos, restricciones (fecha, presupuesto declarado).
2. Definir alcance con entregables medibles y criterios de aceptación.
3. Escribir exclusiones explícitas (hosting, contenidos, fotografía, licencias de apps, inversión publicitaria, etc., según el caso).
4. Cronograma por etapas con hitos y dependencias del cliente.
5. Precios por ítem desde tarifas; subtotal, impuestos según país (marcar "a confirmar con contabilidad" si no está definido en el CRM).
6. Condiciones de pago y vigencia (por defecto 15 días, configurable).
7. Entregar con la plantilla `references/plantilla-propuesta.md` y la lista de decisiones pendientes.

La propuesta queda en estado `draft` hasta que un manager/admin la apruebe en el CRM.
