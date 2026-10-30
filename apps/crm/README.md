# eQuantum CRM (Rails 8)

Núcleo comercial del ecosistema eQuantum Prospect AI + CRM. Ver la arquitectura en [`docs/`](../../docs/README.md).

## Requisitos
Ruby 3.3.6, PostgreSQL 16 (local o `docker compose -f infrastructure/compose.dev.yml up -d`). No requiere Redis: los trabajos en segundo plano usan Solid Queue.

## Puesta en marcha
```bash
cd apps/crm
cp .env.example .env            # completar ADMIN_EMAIL y ADMIN_PASSWORD (mín. 12 caracteres)
bundle install
bin/rails db:prepare            # crea la base, migra y carga datos de referencia
ADMIN_EMAIL=... ADMIN_PASSWORD=... bin/rails db:seed   # crea el primer administrador
bin/dev                         # http://localhost:3000
```
Las semillas solo cargan datos de referencia (roles, permisos, países, servicios, fuentes, etapas, rúbrica). **No cargan tarifas, prospectos ni datos ficticios.**

## Calidad
```bash
bin/rails test        # pruebas de modelos, servicios e integración
bin/brakeman          # análisis de seguridad
bin/bundler-audit     # dependencias vulnerables
bin/rubocop           # estilo
```
CI: `.github/workflows/crm.yml`.

## Módulos implementados (Fase 02)
| Módulo | Qué hace |
|---|---|
| Autenticación | Sesiones con expiración (14 días), contraseñas bcrypt (mín. 12), límite de intentos, usuarios inactivos bloqueados |
| Roles y permisos | 5 roles, 14 permisos como datos; Pundit verifica cada acción |
| Prospectos | Captura rápida (enlace + extracto), detección de duplicados por URL canónica, evidencia, verificación, puntuación por rúbrica de 8 criterios, calificación, descarte con motivo, conversión a oportunidad |
| Análisis de Claude | Se pega el JSON/YAML de la Skill `eq-lead-qualifier`; queda pendiente hasta que alguien lo acepta; Rails calcula la puntuación final |
| Empresas | CRUD con dominio único, servicios de interés, historial |
| Pipeline | 10 etapas, Kanban con arrastrar y soltar, tabla, motivo obligatorio al perder, registro automático de cambios de etapa |
| Actividades | Llamadas, reuniones, tareas, seguimientos, recordatorios y notas; vista "Mis pendientes" |
| Tarifas | Rango aprobado por servicio, país, moneda, modalidad y vigencia, con responsable; sin tarifa = "Precio pendiente de aprobación" |
| Dashboard | KPIs calculados con datos reales y filtros por fecha, país, servicio, fuente y responsable |
| Administración | Usuarios, tarifas y registro de auditoría |
