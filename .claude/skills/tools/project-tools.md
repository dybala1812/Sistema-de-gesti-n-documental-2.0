# Herramientas del Proyecto

## Comandos

| Acción | Backend (`backned_sistema_gestion_documental/`) | Frontend (`NOVA_FT/`) |
|---|---|---|
| Desarrollo | `npm run dev` (puerto 3000) | `npm run dev` (puerto 5173) |
| Tipos | `npx tsc --noEmit -p .` | `npm run typecheck` (línea base 28) |
| Lint | `npm run lint` | — |
| Tests | `npm test` | — |
| Build | `npm run build` | `npx vite build` |

Base de datos: `bash database/scripts/probar_local.sh` (desde la raíz) y `node database/scripts/verificar_supabase.mjs` (revisa qué migraciones faltan en Supabase).

## Librerías clave

- `@supabase/supabase-js` — acceso a PostgreSQL y RPC de funciones desde el backend.
- `sileo` — alertas de estado (toasts) en el frontend.
- `xlsx` — lectura de Excel/CSV en importaciones y descarga de plantillas.
- shadcn/ui (Radix) — componentes de interfaz de NOVA.

## Variables de entorno

Backend (`.env.local`): `NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `NOVA_API_URL`, `RAIZ_ARCHIVOS`, `PORT`, `ALLOWED_ORIGINS`, `SGD_DEV_TOKEN` (solo desarrollo), `N8N_SERVICE_TOKEN`, `N8N_WEBHOOK_RECORDATORIO_URL`, `N8N_WEBHOOK_RESPONDER_URL`.
Frontend (`NOVA_FT/.env`): `VITE_SGD_API_URL`, `VITE_DEV_BYPASS_AUTH`, `VITE_SGD_DEV_TOKEN` (solo desarrollo).

## Hosting / despliegue

Por decidir (ver P-11 en `ia_contexto/spec/decisiones.md`). Supabase es el servicio gestionado de la base de datos.
