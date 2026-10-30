# 00 — Diagnóstico inicial (Fase 01)

Fecha del diagnóstico: 2026-10-30.

## 1. Estado real del repositorio

| Elemento | Estado verificado |
|---|---|
| Repositorio | `equantum-py/equantumcrm` (privado), acceso de lectura y escritura confirmado desde esta sesión |
| Rama `main` | 1 commit (`05b1de8 Create README.md`, 2026-10-30). Único archivo: `README.md` |
| Código existente | Ninguno. No hay Rails, Python, Docker, CI ni migraciones |
| README | Describe las 5 responsabilidades del sistema (buscar, investigar, calificar, preparar contacto, medir). Sin instrucciones técnicas |
| Rama de trabajo | `claude/project-thread-up3moa` (creada desde `main`, `main` no se modifica) |

Conclusión: el proyecto parte de cero. No hay decisiones técnicas previas que respetar ni deuda que migrar.

## 2. Herramientas verificadas en esta sesión de Claude

Verificado ejecutando comandos y consultando el catálogo de herramientas, no por suposición.

| Herramienta | Disponible | Observación |
|---|---|---|
| Git + GitHub (lectura/escritura, PRs) | Sí | Solo sobre `equantum-py/equantumcrm` |
| Ruby 3.3.6 | Sí | Rails no está instalado como gema global; se instala por `bundle` en Fase 02 |
| Python 3.13 + Pydantic 2 | Sí | FastAPI no instalado aún; se instala en Fase 03 |
| PostgreSQL client / Redis server | Sí | Disponibles para pruebas locales en la sesión |
| Docker daemon | No | El binario existe pero el daemon no corre en esta sesión. Docker se valida en CI (GitHub Actions) |
| Node 22 | Sí | Útil para Tailwind standalone si hiciera falta |
| Búsqueda web y lectura de páginas públicas | Sí | Útil para Google Search, documentación, comunidades públicas |
| Claude in Chrome / navegador con sesión del usuario | **No** en esta sesión | No hay herramientas de navegador conectadas. Sin esto no se puede leer Facebook ni LinkedIn con sesión iniciada |
| Conectores MCP de Facebook, LinkedIn, Google Maps | **No** | No existen conectores conectados para esas plataformas |
| Conectores conectados no relevantes | Figma, Tally, Claude Docs | Figma puede servir para diseño UI; Tally para formularios de captación propia |

Implicancia directa: **en esta sesión Claude no puede acceder a Facebook ni LinkedIn**. Cualquier afirmación en contrario sería falsa. Ver `06-fuentes-y-facebook.md` para la alternativa viable.

## 3. Restricciones de plataformas verificadas

Resumen (detalle y fuentes en `06-fuentes-y-facebook.md`):

- **Facebook Groups API**: Meta retiró el acceso a Grupos vía API en abril de 2024. No hay forma oficial de leer grupos por API.
- **Meta Content Library**: solo para instituciones de investigación sin fines de lucro. eQuantum no es elegible para uso comercial.
- **Google Custom Search JSON API**: cerrada a clientes nuevos y con cierre anunciado para el 1 de enero de 2027. No conviene construir sobre ella.
- **Scraping de Facebook/LinkedIn**: prohibido por sus condiciones de uso. Descartado.

## 4. Formato de Skills de Claude verificado

Fuente: documentación oficial de Agent Skills (platform.claude.com) y de Claude Code (code.claude.com), consultadas el 2026-10-30.

- Cada Skill es un directorio con `SKILL.md` (obligatorio) y recursos opcionales.
- Frontmatter YAML obligatorio: `name` (≤ 64 caracteres, minúsculas, números y guiones, sin las palabras reservadas `anthropic` ni `claude`) y `description` (≤ 1024 caracteres, debe decir qué hace y cuándo usarla).
- Carga progresiva: metadatos siempre; cuerpo al activarse (recomendado < 5k tokens); recursos solo cuando se leen.
- Una Skill **no** es un proceso autónomo: no corre sola ni en segundo plano. Los procesos programados se diseñan como servicios externos (ver arquitectura).
- Las Skills no se sincronizan entre superficies: en Claude Code se instalan en `.claude/skills/`; en claude.ai se suben como zip; en la API por el endpoint de skills.

El repositorio incluye `scripts/validate_skills.py`, que verifica estas reglas en CI.
