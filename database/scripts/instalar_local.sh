#!/usr/bin/env bash
# =============================================================================
#  Instala o actualiza la base del SGD en un PostgreSQL propio (D-29, D-31).
#  1. Aplica, en orden, las migraciones de migrations/ que falten. Lleva la cuenta en la
#     tabla sgd_migracion: se puede correr en cada actualización, solo aplica lo nuevo.
#  2. Carga seed.sql (idempotente). Nunca carga seed_demo.sql.
#  3. Crea o actualiza el rol con el que se conecta el backend ($SGD_BACKEND_ROLE, por defecto
#     sgd_backend): puede entrar, salta RLS, lee, inserta y actualiza (sin delete: no hay borrado
#     físico) y ejecuta las funciones; no es dueño de
#     nada ni superusuario (no puede borrar tablas ni cambiar la estructura).
#
#  Uso:  DATABASE_URL=postgres://postgres:<clave>@<host>:5432/sgd \
#        SGD_BACKEND_PASSWORD=<clave del backend> ./scripts/instalar_local.sh
#        En Docker lo corre el servicio "migraciones" de despliegue/docker-compose.yml.
#        DATABASE_URL debe ser un superusuario (crea extensiones y el rol del backend).
#        Sin SGD_BACKEND_PASSWORD no crea el rol (solo migraciones y permisos, si ya existe).
#  Base restaurada desde un respaldo que ya tiene todo:
#        MARCAR_APLICADAS=1 DATABASE_URL=... ./scripts/instalar_local.sh   (solo registra, no aplica)
# =============================================================================
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
: "${DATABASE_URL:?Falta DATABASE_URL (postgres://usuario:clave@host:puerto/base)}"
ROL="${SGD_BACKEND_ROLE:-sgd_backend}"
PSQL=(psql "$DATABASE_URL" -X -q -v ON_ERROR_STOP=1)
export PGOPTIONS="${PGOPTIONS:--c client_min_messages=warning}"   # sin avisos "ya existe"

"${PSQL[@]}" -c "create table if not exists sgd_migracion (
  nombre      text primary key,
  aplicada_en timestamptz not null default now())" \
  -c "alter table sgd_migracion enable row level security"

aplicadas=0
for f in "$RAIZ"/migrations/*.sql; do
  n="$(basename "$f")"
  if [ "$("${PSQL[@]}" -At -c "select 1 from sgd_migracion where nombre = '$n'")" = "1" ]; then
    continue
  fi
  if [ "${MARCAR_APLICADAS:-0}" != "1" ]; then
    echo ">>> Aplicando $n"
    "${PSQL[@]}" -f "$f"
  fi
  "${PSQL[@]}" -c "insert into sgd_migracion (nombre) values ('$n')"
  aplicadas=$((aplicadas + 1))
done
echo ">>> Migraciones nuevas: $aplicadas"

if [ "${MARCAR_APLICADAS:-0}" != "1" ]; then
  echo ">>> Cargando seed.sql"
  "${PSQL[@]}" -f "$RAIZ/seed.sql"
fi

if [ -n "${SGD_BACKEND_PASSWORD:-}" ]; then
  echo ">>> Rol del backend: $ROL"
  "${PSQL[@]}" -v rol="$ROL" -v clave="$SGD_BACKEND_PASSWORD" <<'SQL'
select format('create role %I', :'rol') where not exists (select 1 from pg_roles where rolname = :'rol') \gexec
alter role :"rol" with login bypassrls nosuperuser nocreatedb nocreaterole noreplication password :'clave';
SQL
fi

# Permisos del backend (se repiten en cada corrida: cubren las tablas y funciones nuevas).
"${PSQL[@]}" -v rol="$ROL" <<'SQL'
select exists (select 1 from pg_roles where rolname = :'rol') as hay_rol \gset
\if :hay_rol
  -- Solo el backend y el dueño se conectan a la base.
  select format('revoke all on database %I from public', current_database()) \gexec
  select format('grant connect, temporary on database %I to %I', current_database(), :'rol') \gexec
  grant usage on schema public to :"rol";
  grant select, insert, update on all tables in schema public to :"rol";   -- sin delete: no hay borrado físico (RN-AC)
  grant usage, select, update on all sequences in schema public to :"rol";
  grant execute on all functions in schema public to :"rol";
  alter default privileges in schema public grant select, insert, update on tables to :"rol";
  alter default privileges in schema public grant usage, select, update on sequences to :"rol";
  alter default privileges in schema public grant execute on functions to :"rol";
\else
  \echo '!!! No existe el rol del backend: defina SGD_BACKEND_PASSWORD para crearlo'
\endif
SQL
echo ">>> Base lista"
