#!/usr/bin/env bash
# =============================================================================
#  Instala o actualiza la base del SGD en un PostgreSQL propio (producción sin Supabase, D-29).
#  1. Aplica, en orden, las migraciones de supabase/migrations/ que falten. Lleva la cuenta en la
#     tabla sgd_migracion: se puede correr en cada actualización, solo aplica lo nuevo.
#  2. Carga seed.sql (idempotente). Nunca carga seed_demo.sql.
#  3. Da a service_role (el rol que usa el backend a través de PostgREST) acceso a todo.
#
#  Uso:  DATABASE_URL=postgres://postgres:<clave>@<host>:5432/sgd ./scripts/instalar_local.sh
#        En Docker lo corre el servicio "migraciones" de despliegue/docker-compose.yml.
#  Base restaurada desde un respaldo de Supabase (ya tiene todo):
#        MARCAR_APLICADAS=1 DATABASE_URL=... ./scripts/instalar_local.sh   (solo registra, no aplica)
#  Requiere que existan los roles de despliegue/postgres/00_roles.sh.
# =============================================================================
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
: "${DATABASE_URL:?Falta DATABASE_URL (postgres://usuario:clave@host:puerto/base)}"
PSQL=(psql "$DATABASE_URL" -X -q -v ON_ERROR_STOP=1)

"${PSQL[@]}" -c "create table if not exists sgd_migracion (
  nombre      text primary key,
  aplicada_en timestamptz not null default now())" \
  -c "alter table sgd_migracion enable row level security"

aplicadas=0
for f in "$RAIZ"/supabase/migrations/*.sql; do
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
  "${PSQL[@]}" -f "$RAIZ/supabase/seed.sql"
fi

"${PSQL[@]}" -c "do \$\$ begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant usage on schema public to service_role;
    grant all on all tables in schema public to service_role;
    grant all on all sequences in schema public to service_role;
    grant execute on all functions in schema public to service_role;
  end if;
end \$\$" -c "notify pgrst, 'reload schema'"
echo ">>> Base lista"
