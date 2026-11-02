# equantumcrm

**eQuantum ARM (Agentic Relationship Management)** — plataforma comercial de eQuantum Consulting que evoluciona el CRM: agentes de IA detectan y analizan oportunidades, preparan borradores y sugieren seguimientos; las personas aprueban todo lo que sale hacia un cliente. Plan de transición: [`docs/10-arm-auditoria-y-transicion.md`](docs/10-arm-auditoria-y-transicion.md).

Módulos: **Prospect AI** (captación y verificación), **Sales Intelligence** (scoring y priorización), **Sales Agent** (borradores), **Relationship Hub** (empresas, pipeline, actividades) y **Agent Control** (agentes, ejecuciones, aprobaciones y auditoría).

El sistema tiene cinco responsabilidades:
1. Buscar oportunidades: detectar personas y empresas que estén solicitando servicios digitales.
2. Investigar prospectos: identificar qué necesita cada negocio y qué servicio puede ofrecer eQuantum.
3. Calificar oportunidades: diferenciar a quien realmente quiere contratar de quien solamente está consultando.
4. Preparar el contacto comercial: generar mensajes personalizados, propuestas y seguimientos.
5. Medir resultados: registrar oportunidades, reuniones, presupuestos y clientes conseguidos.

## Estado

**Fase 02 — Fundamentos del CRM.** CRM Rails funcional en entorno de desarrollo; Prospect AI (Python) pendiente de Fase 03.

| Componente | Ruta | Estado |
|---|---|---|
| CRM (Ruby on Rails 8, PostgreSQL, Hotwire, Tailwind) | [`apps/crm/`](apps/crm/README.md) | Núcleo funcional en desarrollo (Fase 02) |
| Prospect AI (Python, FastAPI, Pydantic) | `services/prospect-ai/` | Diseñado — se crea en Fase 03 |
| Skills de Claude (8) | [`skills/`](skills/) | Escritas v1, validadas en CI |
| Documentación | [`docs/`](docs/README.md) | Fase 01 |

## Validar las Skills

```bash
python3 scripts/validate_skills.py skills
```
