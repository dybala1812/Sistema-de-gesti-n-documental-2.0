# Despliegue en producción — SGD · Módulo Archivo Central

Guía para instalar, operar y actualizar el backend y la base de datos del módulo en un servidor propio, con **PostgreSQL 18 propio y sin Supabase** (D-29, D-31). El frontend se publica dentro de NOVA, con el proceso de NOVA (ver §8).

```text
Internet ──HTTPS──► nova.<dominio>  (nginx del frontend de NOVA, lo publica el equipo de NOVA)
                        ├── /            → frontend de NOVA (incluye el módulo Archivo Central)
                        └── /sgd-api/... → sgd_backend:3000/api/...   (red de Docker de NOVA: RED_NOVA)
                                                │ backend del SGD (contenedor "backend")
                                                ▼ red interna de este docker compose
                                         PostgreSQL 18 (contenedor "db", sin puerto publicado)
Volúmenes: datos_postgres (la base) · archivos_sgd (los documentos escaneados)
```

El backend no necesita dominio ni certificado propios: queda bajo el dominio de NOVA, igual que las otras apps que NOVA publica (`/quiz-app/`, `/reportes-app/`…). Si se prefiere un dominio propio, ver la alternativa del §6.

## 1. Qué falta definir (no sale del código)

| Dato | Para qué | Quién lo da |
| --- | --- | --- |
| **Servidor** (propio de la universidad, VPS o nube) y su sistema operativo | Dónde corre Docker | TI de la universidad |
| **Nombre de la red de Docker de NOVA** en el servidor (`docker network ls`) | `RED_NOVA`: el nginx de NOVA alcanza el backend por ella | Equipo de NOVA / TI |
| **URL del backend de NOVA** accesible desde el servidor | `NOVA_API_URL` (valida cada token) | Equipo de NOVA |
| **URL pública del frontend de NOVA** | `ALLOWED_ORIGINS` (CORS) | Equipo de NOVA |
| **Destino de los respaldos fuera del servidor** (NAS, otro disco, almacenamiento institucional) | Copias de seguridad | TI |
| **n8n** (si se activa la Bandeja de comunicaciones) y el buzón institucional | Flujos F1–F6 | Equipo + TI |
| **Zona horaria de la base** (`UTC`, como hasta ahora, o `America/Bogota`) | Define el "hoy" de plazos y el año de los consecutivos | Archivo Central (ver §11) |

### Dónde alojar PostgreSQL: alternativas

| Opción | Cuándo | Cómo |
| --- | --- | --- |
| **A. Contenedor en el mismo servidor** (recomendada, la que trae `docker-compose.yml`) | Un solo servidor; volumen de datos moderado | Tal como está esta guía. La base no se publica en la red. |
| **B. Servidor PostgreSQL institucional o gestionado** (no Supabase) | TI ya opera PostgreSQL, o se quiere separar la base | PostgreSQL 15+ con `pg_trgm` y `unaccent`. Correr `instalar_local.sh` contra ese servidor (§5.3) y en `docker-compose.yml` quitar los servicios `db` y `migraciones` y poner `DATABASE_URL=postgres://sgd_backend:<clave>@<host>:5432/sgd?sslmode=require` en el backend. |

## 2. Requisitos del servidor

- Linux de 64 bits (Ubuntu 22.04/24.04 LTS o Debian 12 probados por la comunidad de Docker).
- **Docker Engine 24+** y **Docker Compose v2** (`docker compose version`).
- Mínimo sugerido: **2 vCPU, 4 GB de RAM**, disco SSD para la base y espacio para los archivos escaneados (las historias académicas ocupan la mayor parte: estimar el total de PDF + 30 % y crecer según la carga anual), más el mismo espacio para respaldos locales.
- Salida a internet al construir la imagen (descarga de paquetes npm y de las imágenes `node:24-alpine` y `postgres:18-alpine`).
- Acceso de red del servidor al backend de NOVA.
- Puertos abiertos al público: solo **443** (y 80 para redirigir/renovar el certificado). El 3000 y el 5432 **no** se abren.

## 3. Preparación del entorno

```bash
# Docker (Ubuntu/Debian; ver docs.docker.com/engine/install)
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER      # cerrar y abrir sesión

# Código: la rama main trae solo backend, base y despliegue
sudo mkdir -p /opt/sgd && sudo chown $USER /opt/sgd
git clone -b main https://github.com/dybala1812/Sistema-de-gesti-n-documental-2.0.git /opt/sgd
cd /opt/sgd/despliegue
```

`main` no incluye el frontend, la spec (`ia_contexto/`) ni las skills: esos quedan en la rama `master` y en el repo de NOVA.

## 4. Variables de entorno

```bash
cp .env.ejemplo .env
chmod 600 .env
openssl rand -hex 32     # una vez para POSTGRES_PASSWORD y otra para SGD_BACKEND_PASSWORD
```

Use claves **hexadecimales** (`-hex`): van dentro de una URL de conexión y caracteres como `/ + @ :` la romperían.

| Variable | Obligatoria | Valor |
| --- | --- | --- |
| `POSTGRES_PASSWORD` | Sí | Clave del superusuario `postgres` (solo migraciones y administración) |
| `SGD_BACKEND_PASSWORD` | Sí | Clave del rol `sgd_backend`, con el que se conecta el backend |
| `NOVA_API_URL` | Sí | Backend de NOVA, sin `/api` al final (p. ej. `https://nova-api.<dominio>`) |
| `ALLOWED_ORIGINS` | Sí | URL pública del frontend de NOVA (p. ej. `https://nova.<dominio>`); varias, separadas por comas |
| `RED_NOVA` | Sí | Red de Docker donde corre NOVA (`docker network ls`). El backend se une con el alias `sgd_backend` |
| `PUERTO_BACKEND` | No | Puerto del backend en el propio servidor, para revisar `/api/salud`. Por defecto `127.0.0.1:3000` (no se abre al público) |
| `TZ` | No | Zona horaria de los contenedores (`UTC` por defecto) |
| `N8N_SERVICE_TOKEN` | Con la Bandeja | Token largo y aleatorio que n8n envía al backend (`openssl rand -hex 32`) |
| `N8N_WEBHOOK_REMITIR_URL`, `N8N_WEBHOOK_RESPONDER_URL`, `N8N_WEBHOOK_RECORDATORIO_URL` | Con la Bandeja | URL de los webhooks de n8n que dispara el backend |

El backend recibe además, desde `docker-compose.yml`: `DATABASE_URL=postgres://sgd_backend:${SGD_BACKEND_PASSWORD}@db:5432/sgd` y `RAIZ_ARCHIVOS=/data/archivos` (en el `Dockerfile`). No existen ni se usan variables `SUPABASE_*`.

`.env` nunca se sube a Git (está en `.gitignore`) ni se envía por chat o correo.

## 5. PostgreSQL

### 5.1 Qué levanta `docker-compose.yml`

| Servicio | Qué hace | ¿Publicado? |
| --- | --- | --- |
| `db` | `postgres:18-alpine`, base `sgd`, datos en el volumen `datos_postgres` (`/var/lib/postgresql`) | No (solo red interna) |
| `migraciones` | Corre `database/scripts/instalar_local.sh`: aplica las migraciones que falten (tabla `sgd_migracion`), carga `seed.sql`, crea o actualiza el rol `sgd_backend` y sus permisos. Termina y se apaga | No |
| `backend` | Arranca solo si `migraciones` terminó bien | `127.0.0.1:3000` |

### 5.2 Roles

| Rol | Uso | Permisos |
| --- | --- | --- |
| `postgres` | Migraciones, respaldos, administración | Superusuario. Nunca lo usa el backend |
| `sgd_backend` | El backend | `login`, salta RLS, `select/insert/update` en tablas, secuencias y `execute` en funciones. **Sin `delete`** (no hay borrado físico) y sin poder cambiar la estructura |

RLS está activo en todas las tablas, sin políticas: nadie más que estos dos roles lee o escribe. `connect` a la base está revocado para `public`.

### 5.3 Instalar en un PostgreSQL fuera de Docker (opción B)

```bash
psql "postgres://<superusuario>@<host>:5432/postgres" -c "create database sgd"
DATABASE_URL="postgres://<superusuario>:<clave>@<host>:5432/sgd" SGD_BACKEND_PASSWORD="<clave>" \
  bash database/scripts/instalar_local.sh          # requiere psql 15+ en la máquina que lo corre
```

### 5.4 Datos iniciales

Una base nueva trae parámetros, plantillas, permisos por perfil, tipos documentales y niveles, pero **no** dependencias, TRD ni asuntos:

- **Empezar de cero:** un Administrador los carga en Administración › Catálogos (importación desde Excel). `database/datos/dependencias.sql` trae las dependencias reales, si se quieren cargar con `psql`.
- **Traer los datos de la base anterior** (la de pruebas del equipo, alojada en Supabase): ver §10. Es una migración de datos única; después Supabase no se usa más.
- **Nunca** cargar `seed_demo.sql` en producción.

## 6. Backend

Imagen `sgd-backend` construida desde `backned_sistema_gestion_documental/Dockerfile` (Next.js standalone, Node 24, usuario sin privilegios). Los archivos subidos van al volumen `archivos_sgd` (`/data/archivos`), nunca dentro de la imagen. `HEALTHCHECK` contra `GET /api/salud`, que responde `{"ok":true,"bd":true}` solo si llega a PostgreSQL.

### Publicación: dentro del dominio de NOVA (forma principal)

El `nginx.conf` del frontend de NOVA tiene la ruta `/sgd-api/`, que pasa cada petición a `sgd_backend:3000/api/` por la red de Docker de NOVA, con subidas de hasta 50 MB. Para que funcione:

1. Poner en `.env` el nombre de esa red: `RED_NOVA=<red de NOVA>` (`docker network ls`; suele ser `<carpeta del compose de NOVA>_default`).
2. Levantar este compose **después** de NOVA (la red debe existir). Si el backend aún no está, solo `/sgd-api/` responde 502; el resto de NOVA sigue funcionando.
3. Comprobar desde el servidor: `docker compose exec backend wget -qO- http://localhost:3000/api/salud` y, ya publicado, `curl -s https://nova.<dominio>/sgd-api/salud`.

### Alternativa: dominio propio para el backend

Si TI prefiere publicar el backend en su propio dominio, el frontend de NOVA se construye con `VITE_SGD_API_URL=https://sgd-api.<dominio>/api` y delante del puerto 3000 va un proxy con HTTPS (ejemplo Nginx):

```nginx
server {
    listen 443 ssl http2;
    server_name sgd-api.<dominio>;
    ssl_certificate     /etc/letsencrypt/live/sgd-api.<dominio>/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/sgd-api.<dominio>/privkey.pem;

    client_max_body_size 60m;          # el parámetro tamano_maximo_archivo_mb es 50 MB por archivo
    proxy_read_timeout 300s;           # cargas masivas e importaciones

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
server { listen 80; server_name sgd-api.<dominio>; return 301 https://$host$request_uri; }
```

Certificado: `sudo certbot --nginx -d sgd-api.<dominio>` (o el certificado institucional).

## 7. Ejecución

```bash
cd /opt/sgd/despliegue
docker compose up -d --build
docker compose ps                                   # db healthy · migraciones exited (0) · backend healthy
docker compose logs migraciones | tail -5           # ">>> Base lista"
curl -s http://127.0.0.1:3000/api/salud             # {"ok":true,"bd":true}
curl -s https://nova.<dominio>/sgd-api/salud       # a través del nginx de NOVA
```

**Primer administrador**, después de que la persona entre al módulo por primera vez desde NOVA:

```bash
docker compose exec db psql -U postgres -d sgd -c "update usuario set perfil = 'administrador' where email = '<correo institucional>';"
```

Ese Administrador asigna después el perfil de cada persona en Administración › Catálogos › Usuarios.

**Quién entra:** en NOVA, rol *área* (D-30); en el SGD, un perfil (Archivo Central, Dependencia, Registro Académico, Secretaría General o Administrador). Sin perfil, el backend responde 403.

Comandos útiles: `docker compose logs -f backend`, `docker compose restart backend`, `docker compose down` (detiene; **no** borra volúmenes). **Nunca** `docker compose down -v` en producción: borra la base y los archivos.

## 8. Frontend (dentro de NOVA)

El módulo se publica con el frontend de NOVA (repo `DavidM3-M/NOVA_FT`, rama `desarrollo-archivo-central` → `main` de NOVA, que lleva su equipo):

- **No necesita variables del SGD.** Sin `VITE_SGD_API_URL`, el módulo llama a `/sgd-api` en el mismo dominio de NOVA y el `nginx.conf` de NOVA lo pasa al backend (§6). `VITE_SGD_API_URL` solo se usa en desarrollo o con la alternativa de dominio propio.
- El `nginx.conf` de NOVA ya permite `blob:` en `frame-src` (visor de PDF).
- No lleva tokens ni claves del SGD: nada sensible va en variables `VITE_*`.
- `ALLOWED_ORIGINS` del backend: el origen público de NOVA (p. ej. `https://nova.<dominio>`).

## 9. Persistencia y copias de seguridad

Los datos viven en dos volúmenes de Docker, que sobreviven a reinicios, `docker compose down` y nuevas versiones de la imagen:

| Volumen | Contenido |
| --- | --- |
| `despliegue_datos_postgres` | La base (tablas, auditoría, consecutivos) |
| `despliegue_archivos_sgd` | Los archivos (PDF, adjuntos), en carpetas |

(El prefijo es el nombre de la carpeta: confirmar con `docker volume ls`.)

**Se respaldan juntos**: la base referencia cada archivo por su id (RN-AC-14); un respaldo de uno sin el otro queda incompleto.

```bash
cd /opt/sgd/despliegue && ./respaldar.sh            # deja respaldos/sgd_<fecha>.dump y respaldos/archivos_<fecha>.tgz
crontab -e                                          # diario a las 2:00, conserva 30 días (DIAS=…)
0 2 * * * cd /opt/sgd/despliegue && ./respaldar.sh >> respaldos/respaldo.log 2>&1
```

- Copiar `respaldos/` **fuera del servidor** cada día (rsync/rclone al destino institucional). Un respaldo que solo está en el mismo disco no protege de una falla del disco.
- **Probar la restauración** al menos cada trimestre en un servidor de pruebas.

**Restaurar** (en una instalación nueva o tras un desastre):

```bash
docker compose up -d db                                                          # base vacía
docker compose cp respaldos/sgd_<fecha>.dump db:/tmp/sgd.dump
docker compose exec db pg_restore -U postgres -d sgd --clean --if-exists --no-owner --no-privileges /tmp/sgd.dump
docker compose up -d                  # "migraciones": aplica solo las que el respaldo no tenía (trae sgd_migracion), rol y permisos
docker compose cp respaldos/archivos_<fecha>.tgz backend:/tmp/a.tgz
docker compose exec backend sh -c "tar xzf /tmp/a.tgz -C /data/archivos && rm /tmp/a.tgz"
```

## 10. Traer los datos de la base anterior (una sola vez)

Si se quiere conservar lo cargado en la base de pruebas del equipo (Supabase): se copia su esquema `public` y se marcan las migraciones como aplicadas. **Probarlo primero en un servidor de pruebas.**

```bash
docker compose up -d db
# Supabase guardaba pg_trgm/unaccent en el esquema "extensions": se recrea para que el respaldo encaje.
docker compose exec db psql -U postgres -d sgd -c "create schema if not exists extensions; create extension if not exists pg_trgm schema extensions; create extension if not exists unaccent schema extensions; alter database sgd set search_path = \"\$user\", public, extensions;"
docker run --rm -v "$PWD":/r postgres:18-alpine pg_dump "<cadena de conexión directa de la base anterior>" --schema=public --no-owner --no-privileges -Fc -f /r/sgd_anterior.dump
docker compose cp sgd_anterior.dump db:/tmp/sgd_anterior.dump
docker compose exec db pg_restore -U postgres -d sgd --no-owner --no-privileges /tmp/sgd_anterior.dump
docker compose run --rm -e MARCAR_APLICADAS=1 migraciones
docker compose up -d
rm sgd_anterior.dump
```

Revisar antes cuáles migraciones tenía aplicadas la base anterior: las 30 a 33 son recientes. Si faltaba alguna, en vez de `MARCAR_APLICADAS=1` para todas, borrar de `sgd_migracion` las que falten y correr `docker compose run --rm migraciones` para que se apliquen. Después, copiar la carpeta de archivos del backend anterior (`RAIZ_ARCHIVOS`) al volumen `archivos_sgd` (como en la restauración del §9).

## 11. Seguridad

- **Red:** solo 80/443 abiertos; backend publicado en `127.0.0.1`; PostgreSQL sin puerto publicado (para administrarlo, túnel SSH o descomentar `127.0.0.1:5432` en `docker-compose.yml`).
- **Claves:** largas y aleatorias, solo en `despliegue/.env` (`chmod 600`). Rotarlas si se exponen: `SGD_BACKEND_PASSWORD` se cambia en `.env` y `docker compose up -d` (el contenedor de migraciones actualiza el rol). **Rotar `N8N_SERVICE_TOKEN`**, que estuvo en un build local del frontend.
- **Mínimo privilegio:** el backend nunca usa `postgres`; `sgd_backend` no puede borrar filas ni cambiar la estructura.
- **Datos personales (Ley 1581):** el backend no registra parámetros de consultas ni datos personales en los logs; los archivos nunca son públicos (se descargan por id, con sesión y permiso); los respaldos contienen datos personales: cifrarlos o guardarlos en almacenamiento con acceso restringido.
- **Tokens:** cada petición se valida contra NOVA; `SGD_DEV_TOKEN` no existe en producción (la imagen corre con `NODE_ENV=production`).
- **Actualizaciones:** aplicar parches del sistema operativo y de Docker; reconstruir la imagen periódicamente para tomar las correcciones de `node:24-alpine` y `postgres:18-alpine` (las versiones menores de PostgreSQL 18 se actualizan solas al bajar la imagen).
- **Zona horaria:** la base usa `UTC` (igual que en las pruebas). Si Archivo Central necesita que el cambio de día y de año sea a la hora de Colombia, definir `TZ=America/Bogota` y `alter database sgd set timezone = 'America/Bogota';` antes de empezar a registrar (afecta plazos en días hábiles y el año de los consecutivos).

## 12. Actualizar y mantener

```bash
cd /opt/sgd/despliegue
./respaldar.sh                         # siempre antes de actualizar
git pull
docker compose up -d --build           # "migraciones" aplica solo las nuevas; el backend arranca si terminaron bien
docker compose logs migraciones | tail -5
curl -s http://127.0.0.1:3000/api/salud
docker image prune -f                  # limpia imágenes viejas
```

- **Volver a la versión anterior:** `git checkout <commit anterior>` y `docker compose up -d --build`. Las migraciones no se deshacen solas: si la nueva versión aplicó una, restaurar el respaldo del §9.
- **Ver qué migraciones tiene la base:** `docker compose exec db psql -U postgres -d sgd -c "select * from sgd_migracion order by nombre"`.
- **Espacio en disco:** `docker system df` y `du -sh respaldos/`. Vigilar el crecimiento del volumen de archivos.
- **Mantenimiento de la base:** el autovacuum de PostgreSQL está activo; tras cargas masivas grandes, `docker compose exec db psql -U postgres -d sgd -c "vacuum analyze"`.
- **Logs:** `docker compose logs --since 24h backend`. Para que no crezcan sin límite, configurar la rotación de Docker en `/etc/docker/daemon.json` (`"log-opts": {"max-size": "20m", "max-file": "5"}`).
- **Cambios en el código:** se integran en `main` y en el servidor se aplica con `git pull` (arriba).

## 13. Problemas frecuentes

| Síntoma | Causa probable | Qué hacer |
| --- | --- | --- |
| `backend` no arranca y `migraciones` salió con error | Una migración falló | `docker compose logs migraciones`; corregir y `docker compose up -d` |
| `/api/salud` responde 503 `{"bd":false}` | El backend no llega a la base | `docker compose ps db`; revisar `SGD_BACKEND_PASSWORD` (sin caracteres especiales) |
| Error de sistema "Falta aplicar una migración" (número de error MIGRACION) | La base no tiene una función o tabla nueva | `docker compose run --rm migraciones` |
| `/sgd-api/` responde 502 en NOVA | El backend no está en la red de NOVA o está apagado | `docker compose ps`; revisar `RED_NOVA` y que el backend esté `healthy`; `docker network inspect <red> ` debe listar `sgd_backend` |
| `docker compose up` dice "network … declared as external, but could not be found" | `RED_NOVA` no coincide con la red de NOVA, o NOVA no está levantado | `docker network ls` y corregir `RED_NOVA` |
| El módulo no carga en NOVA (CORS) | Solo con la alternativa de dominio propio: `ALLOWED_ORIGINS` no coincide con el origen del frontend | Ajustar `.env` y `docker compose up -d` |
| 403 "Usuario sin acceso al módulo" | La persona no tiene perfil del SGD | Asignarlo en Catálogos › Usuarios (o el primer administrador por SQL) |
