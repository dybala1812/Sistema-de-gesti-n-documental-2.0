# Despliegue — SGD · Módulo Archivo Central

Producción con **base de datos local** (D-29): PostgreSQL propio en Docker, sin Supabase en la nube. El backend no cambia: sigue hablando con la base a través de PostgREST, la misma API que usa Supabase.

## Qué se instala

| Contenedor | Qué hace | ¿Se publica? |
| --- | --- | --- |
| `db` | PostgreSQL 18 con los datos (volumen `datos_postgres`) | No |
| `migraciones` | Aplica las migraciones que falten y `seed.sql`; termina y se apaga | No |
| `postgrest` | API de la base (lo mismo que ofrece Supabase) | No |
| `rest` | Pasa `/rest/v1/` a PostgREST, como espera el backend | No |
| `backend` | Backend Next.js; archivos en el volumen `archivos_sgd` | Sí, puerto 3000, detrás del proxy HTTPS |

Solo el backend queda expuesto. La base y PostgREST viven en la red interna de Docker.

## Lo que debe dar producción

1. **Servidor Linux** con Docker y Docker Compose v2. Mínimo sugerido: 2 CPU, 4 GB de RAM y disco para la base y los archivos escaneados (las historias académicas ocupan la mayor parte).
2. **Dominio y HTTPS** para el backend (por ejemplo `https://sgd-api.<dominio>`), con un proxy inverso (Nginx, Apache o Traefik) que reenvíe al puerto 3000. Subidas de hasta 20 MB.
3. **Acceso de red del backend al backend de NOVA** (`NOVA_API_URL`): con él valida el token de cada usuario.
4. **Respaldos diarios** de los dos volúmenes **juntos**: la base guarda la referencia de cada archivo por su id.
5. **n8n**, solo si se activa la Bandeja de comunicaciones (hoy está oculta en el menú). Si no, sus variables quedan vacías.

## Lo que entregamos nosotros

| Pieza | Dónde |
| --- | --- |
| Backend, base de datos y esta guía | Rama `despliegue-backend` del repositorio principal (sin el frontend de NOVA) |
| Pantallas del módulo | Dentro del frontend de NOVA: rama `desarrollo-archivo-central` de `NOVA_FT`, que el equipo de NOVA lleva a `main` |
| Variables de producción | `despliegue/.env.ejemplo` (sin valores) |
| Estructura de la base | `database/supabase/migrations/` (se aplica sola con el contenedor `migraciones`) |

## Instalación

```bash
git clone -b despliegue-backend <url del repositorio> sgd && cd sgd/despliegue
cp .env.ejemplo .env
openssl rand -base64 48        # una vez por cada clave: POSTGRES_PASSWORD, AUTHENTICATOR_PASSWORD, JWT_SECRET
JWT_SECRET='<el de .env>' node ../database/scripts/generar_clave_servicio.mjs   # → SERVICE_ROLE_KEY
docker compose up -d --build
docker compose logs migraciones          # debe terminar en "Base lista"
curl http://localhost:3000/api/salud     # {"ok":true}
```

Si el servidor no tiene Node para generar la clave: `docker run --rm -e JWT_SECRET='<...>' -v "$PWD/../database/scripts:/s" node:24-alpine node /s/generar_clave_servicio.mjs`.

Variables de `.env`:

| Variable | Valor |
| --- | --- |
| `POSTGRES_PASSWORD`, `AUTHENTICATOR_PASSWORD` | Claves largas y aleatorias |
| `JWT_SECRET` | Mínimo 32 caracteres; firma `SERVICE_ROLE_KEY` |
| `SERVICE_ROLE_KEY` | Resultado de `generar_clave_servicio.mjs` |
| `NOVA_API_URL` | Dirección del backend de NOVA (sin `/api` al final) |
| `ALLOWED_ORIGINS` | Dirección pública del frontend de NOVA, por ejemplo `https://nova.<dominio>` |
| `N8N_*` | Solo si se usa la Bandeja de comunicaciones |

## Datos iniciales

Una base nueva trae parámetros, plantillas, permisos por perfil y tipos documentales, pero **no** las dependencias, la TRD ni los asuntos. Hay dos caminos:

- **Empezar de cero:** un Administrador carga dependencias, TRD y asuntos en Administración › Catálogos (importación desde Excel).
- **Conservar lo que ya está en Supabase:** se trae la base completa (estructura y datos) y solo se marcan las migraciones como aplicadas. Así también llega la versión original de `registrar_transferencia`. **Probarlo primero en un servidor de pruebas.**

```bash
docker compose up -d db          # solo la base: crea la base vacía y los roles
docker compose exec db psql -U postgres -d sgd -c "create schema if not exists extensions; create extension if not exists pg_trgm schema extensions; create extension if not exists unaccent schema extensions; alter database sgd set search_path = \"\$user\", public, extensions;"
# Respaldo de Supabase (Project Settings › Database › cadena de conexión). pg_dump 18 sirve para cualquier versión anterior:
docker run --rm -v "$PWD":/r postgres:18-alpine pg_dump "<cadena de conexión de Supabase>" --schema=public --no-owner --no-privileges -Fc -f /r/sgd_supabase.dump
docker compose cp sgd_supabase.dump db:/tmp/sgd_supabase.dump
docker compose exec db pg_restore -U postgres -d sgd --no-owner --no-privileges /tmp/sgd_supabase.dump
docker compose run --rm -e MARCAR_APLICADAS=1 migraciones   # registra las migraciones sin aplicarlas y da permisos al backend
docker compose up -d
```

Después, copiar la carpeta de archivos del backend actual (`RAIZ_ARCHIVOS`, hoy `archivos_sgd/`) al volumen `archivos_sgd`.

**Primer administrador**, una vez que haya entrado al módulo por primera vez desde NOVA:

```bash
docker compose exec db psql -U postgres -d sgd -c "update usuario set perfil = 'administrador' where email = '<correo institucional>';"
```

Después, ese Administrador asigna el perfil de cada persona en Administración › Catálogos › Usuarios.

## Quién entra

1. En NOVA, la persona debe tener **rol área** (dependencia asignada): el módulo es un botón del Panel de Área y solo ese rol lo abre.
2. En el SGD debe tener un **perfil** (Archivo Central, Dependencia, Registro Académico, Secretaría General o Administrador). Sin perfil, el backend responde 403.

## Frontend (dentro de NOVA)

- Variable de build: `VITE_SGD_API_URL=https://sgd-api.<dominio>/api`.
- No lleva `VITE_LOGIN_TEMPORAL` ni ningún token: el login temporal de pruebas se quitó (SGD-091).
- Se construye y publica con el proceso normal de NOVA.

## Actualizar

```bash
git pull && docker compose up -d --build   # "migraciones" aplica solo las nuevas
```

## Respaldar

```bash
docker compose exec db pg_dump -U postgres -d sgd -Fc > sgd_$(date +%F).dump
docker run --rm -v despliegue_archivos_sgd:/datos -v "$PWD":/respaldo alpine tar czf /respaldo/archivos_$(date +%F).tgz -C /datos .
```

El nombre del volumen lleva delante el nombre de la carpeta (`despliegue_`); se confirma con `docker volume ls`.

## Pendiente antes de salir a producción

- **Rutas de transferencias sin autenticación:** `GET`/`POST /api/transferencias` y `GET /api/transferencias/{id}` no exigen sesión. Cualquiera con acceso a la red podría ver y crear transferencias. Hay que corregirlo antes de publicar.
- **`nivel_formacion` sin RLS** (migración 27). Con la base local el riesgo es menor porque PostgREST no se publica, pero en Supabase la tabla queda abierta a la clave pública.
- **`registrar_transferencia` reconstruida** (migración 31): existía solo en Supabase. Conviene exportar la original con `select pg_get_functiondef('registrar_transferencia'::regproc);` y reemplazarla.
- **Prueba desactualizada** en `pruebas_reglas.sql` ("Registro Académico no ve historias de graduados") desde D-27.
- **Probar el `docker compose` completo** en un servidor de pruebas: el instalador y los permisos se probaron en PostgreSQL 18, pero las imágenes no se construyeron (Docker estaba apagado).
- **Rotar `N8N_SERVICE_TOKEN`**, que estuvo en un build local del frontend.
