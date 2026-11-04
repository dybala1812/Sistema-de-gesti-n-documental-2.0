# Herramientas del Proyecto

## Comandos

| Acción | Backend (`backned_sistema_gestion_documental/`) | Frontend (`NOVA_FT/`) |
|---|---|---|
| Desarrollo | `npm run dev` (puerto 3000) | `npm run dev` (puerto 5173) |
| Tipos | `npx tsc --noEmit -p .` | `npm run typecheck` (línea base 28) |
| Lint | `npm run lint` | — |
| Tests | `npm test` | — |
| Build | `npm run build` | `npx vite build` |

Base de datos: `bash database/scripts/probar_local.sh` (desde la raíz) (`--docker` si no hay PostgreSQL instalado). Migraciones aplicadas en una base: `select * from sgd_migracion`. Integración del backend con la base: `SGD_DB_PRUEBAS_URL=... npm test`.

## Librerías clave

- `pg` — conexión directa a PostgreSQL; `lib/db.ts` da `db.rpc()` (funciones SQL) y `db.from()` (consultas con relaciones por llave foránea).
- `sileo` — alertas de estado (toasts) en el frontend.
- `xlsx` — lectura de Excel/CSV en importaciones y descarga de plantillas.
- shadcn/ui (Radix) — componentes de interfaz de NOVA.

## Variables de entorno

Backend (`.env.local`): `DATABASE_URL`, `DATABASE_POOL_MAX`, `NOVA_API_URL`, `RAIZ_ARCHIVOS`, `PORT`, `ALLOWED_ORIGINS`, `SGD_DEV_TOKEN` (solo desarrollo), `N8N_SERVICE_TOKEN`, `N8N_WEBHOOK_RECORDATORIO_URL`, `N8N_WEBHOOK_RESPONDER_URL`.
Frontend (`NOVA_FT/.env`): `VITE_SGD_API_URL`, `VITE_DEV_BYPASS_AUTH`, `VITE_SGD_DEV_TOKEN` (solo desarrollo).

## Hosting / despliegue

Docker Compose en un servidor propio: PostgreSQL 18 + migraciones + backend (`despliegue/`, D-29, D-31). Guía: `README_DEPLOY.md`.
