# equantumcrm

**eQuantum Prospect AI + CRM** — ecosistema comercial de eQuantum Consulting para detectar oportunidades de contratación de servicios digitales, calificarlas y gestionarlas hasta el cierre.

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
