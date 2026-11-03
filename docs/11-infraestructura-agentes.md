# Fase 05 · Infraestructura para ejecutar agentes (comparación, sin contratar)

Fecha: 02/11/2026. **Dirección no autorizó contratar infraestructura.** Este documento solo compara alternativas. No se creó ninguna cuenta ni se desplegó nada.

## Qué necesita eQuantum ARM para que un agente sea autónomo
1. Rails 8.1 (web) y PostgreSQL 16 siempre encendidos.
2. Un proceso que ejecute trabajos: el worker de Solid Queue (`bin/jobs`) o Solid Queue dentro de Puma (`SOLID_QUEUE_IN_PUMA=1`). Las tareas programadas se definen en `config/recurring.yml`.
3. Prospect AI (FastAPI, sin base de datos) accesible solo desde Rails, por red privada o HTTPS con token.
4. Copias de seguridad de PostgreSQL y un lugar para guardar secretos (token de Prospect AI, `RAILS_MASTER_KEY`).

Sin el punto 2 encendido, ningún agente es autónomo. Esto vale para todas las opciones.

## Sobre los precios
La red de este entorno no permite abrir las páginas oficiales de precios (render.com, hetzner.com, fly.io, railway.com, docs.github.com). Los importes salen de buscadores y reseñas de 2026, con su enlace. **Antes de contratar hay que confirmarlos en la página oficial.** Son precios en USD o EUR sin IVA, por mes.

## Comparación

| Alternativa | Costo mensual aproximado | Compatibilidad Rails / PostgreSQL / FastAPI | Seguridad | Persistencia | Recuperación ante errores | Mantenimiento | Limitaciones |
|---|---|---|---|---|---|---|---|
| **A. VPS propio con Kamal** (Rails 8 lo trae). Una máquina con web, worker, PostgreSQL y FastAPI en contenedores. Ej.: Hetzner CX23 | EUR 5,49 sin IPv4 o EUR 5,99 con IPv4 (subió dos veces en 2026). Copias de seguridad aparte (Hetzner cobra un % del servidor) [1] | Total. Todo corre como contenedores | Depende de nosotros: firewall, actualizaciones del sistema, TLS (Kamal usa Let's Encrypt) | Disco local. Hay que programar volcados de PostgreSQL a otro lugar | Kamal reinicia contenedores. Si cae la máquina, cae todo | **Alto**: parches, copias, monitoreo, espacio en disco | Un solo punto de falla. Requiere alguien con práctica en servidores. Reportes de falta de stock del CX23 en la UE [1] |
| **B. PaaS con web + worker** (Render) | Web Starter USD 7 + worker USD 7 + Postgres Basic-256mb USD 6 + FastAPI como servicio privado USD 7 ≈ **USD 27**. Con Solid Queue dentro de Puma: ≈ USD 20 [2] | Total. Docker o Ruby nativo; FastAPI como servicio privado | TLS y red privada administrados. Secretos en el panel | PostgreSQL administrado con copias según plan | Reinicio automático de procesos. Copias de base administradas | **Bajo** | El plan gratuito duerme y no sirve para worker. Precios cambiaron dos veces en 2026 [2] |
| **B2. PaaS** (Heroku) | Basic USD 7 por proceso (web, worker, FastAPI) + Essential-0 USD 5 ≈ **USD 26** [3] | Total | Administrada | PostgreSQL administrado | Reinicio automático | Bajo | 0,5 GB de RAM por proceso Basic |
| **B3. PaaS por consumo** (Railway) | Hobby USD 5 que incluye USD 5 de consumo; lo que se pase se suma. Para web + worker + Postgres + FastAPI pequeños, estimado USD 10 a 20 [4] | Total | Administrada | Volumen para PostgreSQL | Reinicio automático | Bajo | Costo variable, difícil de fijar de antemano |
| **B4. Fly.io** | Máquinas pequeñas desde ≈ USD 2 a 4 cada una; Managed Postgres Basic USD 38 [5] | Total | Administrada | Postgres administrado caro; uno propio en volumen exige mantenimiento | Reinicio automático | Medio | La base administrada lo vuelve la opción más cara |
| **C. Tareas programadas externas** (GitHub Actions con `schedule`) que ejecutan el colector y envían a la API de ingesta | Gratis dentro de 2.000 min/mes en repos privados (plan Free); luego USD 0,006/min en Linux [6] | Solo ejecuta el colector. **El CRM igual tiene que estar alojado** para recibir la ingesta | El token de ingesta vive en los secretos de GitHub. El CRM queda expuesto a internet | Ninguna propia: depende del CRM | GitHub reintenta y avisa por correo; las ejecuciones programadas pueden retrasarse | Bajo | No reemplaza al servidor del CRM. En repos públicos, GitHub desactiva las tareas programadas tras 60 días sin actividad |
| **D. Ejecución bajo demanda** (una persona corre `bin/rails agents:run[prospect_scout]`) | **USD 0** | Total, en una máquina con el proyecto | Credenciales locales | La base local o la del entorno donde se corra | Si falla, se vuelve a correr; queda registrado en Agent Control | Bajo | **No es autónomo.** Depende de que alguien lo ejecute |
| **E. Reutilizar infraestructura existente**: el sitio equantum.com.py está en Vercel (encabezado `server: Vercel`) | Sin costo extra en el plan actual | **No compatible**: Vercel ejecuta funciones sin servidor (Node, Python, etc.), no un proceso Rails permanente ni PostgreSQL | Administrada | No ofrece PostgreSQL propio | — | — | Cron del plan Hobby limitado a una vez por día y con hora imprecisa [7]; el plan Hobby es para uso no comercial según los términos de Vercel (confirmar). No se tocó el sitio |

## Recomendación
1. **Ahora, sin gasto:** opción D. El colector de Freelancer se ejecuta a mano y cada ejecución queda en Agent Control. Así se mide cuántas oportunidades útiles aparecen antes de pagar nada. Se informa como "manual", nunca como autónomo.
2. **Cuando Dirección apruebe gasto:** opción B (Render) o B2 (Heroku), alrededor de USD 20 a 27 por mes, porque el mantenimiento es bajo y no tenemos a nadie dedicado a servidores. La opción A cuesta menos (≈ EUR 6) pero suma trabajo de mantenimiento y riesgo de un solo servidor.
3. La opción C sirve como complemento solo después de tener el CRM alojado.

## Fuentes (consultadas por buscador el 02/11/2026)
1. Hetzner: [agentdeals.dev](https://agentdeals.dev/hetzner-pricing-2026), [cloudtally.eu](https://cloudtally.eu/hetzner-cloud-prices), [costgoat.com](https://costgoat.com/pricing/hetzner)
2. Render: [frontdeskreview.com](https://frontdeskreview.com/software/managed-postgres/render/), [bex.co](https://bex.co/blog/2026/09/04/render-price-changes-cost-sheet), [budgetforge.dev](https://www.budgetforge.dev/tools/render-pricing-2026)
3. Heroku: [devcenter.heroku.com usage and billing](https://devcenter.heroku.com/ja/articles/usage-and-billing), [heroku.com new low cost plans](https://www.heroku.com/blog/new-low-cost-plans)
4. Railway: [docs.railway.com/pricing/plans](https://docs.railway.com/pricing/plans)
5. Fly.io: [fly.io/pricing.md](https://fly.io/pricing.md), [fly.io/docs/mpg](https://fly.io/docs/mpg)
6. GitHub Actions: [cicdcalculator.com](https://cicdcalculator.com/github-actions-free-tier), [tenki.cloud](https://tenki.cloud/blog/github-actions-runner-pricing-2026)
7. Vercel: [vercel.com/docs/cron-jobs/usage-and-pricing](https://vercel.com/docs/cron-jobs/usage-and-pricing), [vercel.com/docs/limits](https://vercel.com/docs/limits)
