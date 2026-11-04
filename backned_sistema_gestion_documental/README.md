# Backend — SGD · Módulo Archivo Central

API REST del módulo (Next.js 16, solo rutas `app/api`; TypeScript 5). No tiene pantallas propias: las pantallas viven dentro de NOVA (`NOVA_FT/`). Proyecto completo: [README.md](../README.md). Despliegue: [README_DEPLOY.md](../README_DEPLOY.md).

## Cómo funciona

- **Autenticación** (`lib/auth.ts`): cada petición trae el token de NOVA (`Authorization: Bearer …`). El backend lo valida con `GET {NOVA_API_URL}/api/users/perfil/`, sincroniza a la persona en la tabla `usuario` (`fn_sincronizar_usuario_nova`) y revisa que tenga perfil del SGD. No hay login propio.
- **Base de datos** (`lib/db.ts`): conexión directa a PostgreSQL con el driver `pg` (`DATABASE_URL`, rol `sgd_backend`). Ofrece
  - `db.rpc("fn_x", { p_a: 1 })`: llama una función SQL con parámetros por nombre (la lógica de negocio está en la base: consecutivos, estados, permisos, auditoría).
  - `db.from("tabla").select("id, dependencia:dependencia_id(nombre)").eq(…).order(…)`: lecturas y escrituras simples; las relaciones se resuelven con las llaves foráneas (`alias:columna_fk(…)` hacia el padre, `alias:tabla_hija(…)` hacia los hijos, `tabla!nombre_fk(…)` si hay varias).
  - Las dos devuelven `{ data, error, count }`; `error.code` es el SQLSTATE de PostgreSQL (`23505` duplicado, `42883` falta una función → migración pendiente, `08006` sin conexión…).
- **Errores** (`lib/errors.ts`): contrato único de errores (formulario 4xx con campo y tipo; sistema 5xx con número de catálogo).
- **Archivos** (`lib/archivos.ts`): se guardan en carpetas bajo `RAIZ_ARCHIVOS`; la tabla `archivo` guarda id, ruta relativa, hash SHA-256 y metadatos. Nunca binarios en la base; se descargan por id con permiso.
- **n8n** (`lib/n8n.ts`, `app/api/n8n/*`): APIs que llaman los flujos de la Bandeja de comunicaciones con `N8N_SERVICE_TOKEN`.
- **CORS** (`middleware.ts`): solo los orígenes de `ALLOWED_ORIGINS`.
- **Salud**: `GET /api/salud` → `{ ok, bd }` (503 si no llega a PostgreSQL). La usa el `HEALTHCHECK` del `Dockerfile`.

## Desarrollo

```bash
cp .env.example .env.local          # completar DATABASE_URL, NOVA_API_URL…
docker compose -f ../despliegue/docker-compose.dev.yml up -d   # PostgreSQL 18 en localhost:5432 con migraciones
npm install
npm run dev                         # http://localhost:3000
```

Sin NOVA a mano: definir `SGD_DEV_TOKEN` en `.env.local` y enviar ese valor como token (solo con `next dev`; en producción no existe).

## Pruebas

```bash
npm test                            # unitarias (errores, búsqueda); la de integración se omite sin base
SGD_DB_PRUEBAS_URL=postgres://sgd_backend:sgd_backend_dev@localhost:5432/sgd npm test   # + integración de lib/db.ts
npx tsc --noEmit                    # tipos
npm run lint
npm run build                       # build de producción (standalone, el mismo de la imagen Docker)
```

La prueba de integración escribe filas: úsela solo con la base de desarrollo (con `seed_demo.sql` cargado), nunca con la de producción.

## Variables de entorno

| Variable | Obligatoria | Uso |
| --- | --- | --- |
| `DATABASE_URL` | Sí | `postgres://sgd_backend:<clave>@<host>:5432/sgd` (agregar `?sslmode=require` si la base está en otro servidor) |
| `DATABASE_POOL_MAX` | No | Conexiones simultáneas a la base (10) |
| `NOVA_API_URL` | Sí | Backend de NOVA que valida los tokens (sin `/api` al final) |
| `ALLOWED_ORIGINS` | Sí | Orígenes del frontend de NOVA, separados por comas |
| `RAIZ_ARCHIVOS` | No | Carpeta de los archivos (`./archivos_sgd`; en Docker `/data/archivos`) |
| `N8N_SERVICE_TOKEN`, `N8N_WEBHOOK_*_URL` | Solo con la Bandeja | Token que usa n8n y webhooks que dispara el backend |
| `SGD_DEV_TOKEN` | Solo desarrollo | Token de pruebas sin NOVA; vacío en producción |
