#!/usr/bin/env bash
# =============================================================================
#  Prueba la base de datos en un PostgreSQL temporal (no toca servicios existentes).
#  1. Crea un clúster en una carpeta temporal y lo levanta en el puerto $PUERTO.
#  2. Aplica migraciones, seed.sql y seed_demo.sql.
#  3. Ejecuta tests/pruebas_reglas.sql y una prueba de concurrencia de consecutivos.
#  4. Apaga y borra el clúster.
#
#  Uso:  PG_BIN="/c/Program Files/PostgreSQL/18/bin" ./scripts/probar_local.sh
# =============================================================================
set -euo pipefail

PG_BIN="${PG_BIN:-/c/Program Files/PostgreSQL/18/bin}"
PUERTO="${PUERTO:-54329}"
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
TMP="${TMPDIR:-${TEMP:-/tmp}}/sgd_pg_$$"
PSQL=("$PG_BIN/psql" -X -q -h localhost -p "$PUERTO" -U postgres -v ON_ERROR_STOP=1)

limpiar() {
  "$PG_BIN/pg_ctl" -D "$TMP/data" stop -m fast >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap limpiar EXIT

echo ">>> Creando clúster temporal en $TMP (puerto $PUERTO)"
mkdir -p "$TMP"
"$PG_BIN/initdb" -D "$TMP/data" -U postgres -A trust -E UTF8 --locale=C >/dev/null
"$PG_BIN/pg_ctl" -D "$TMP/data" -o "-p $PUERTO" -l "$TMP/pg.log" -w start >/dev/null
"${PSQL[@]}" -d postgres -c "create database sgd_test"

# Simula los roles de Supabase para probar los revoke.
"${PSQL[@]}" -d sgd_test -c "create role anon nologin; create role authenticated nologin;"

echo ">>> Aplicando migraciones"
for f in "$RAIZ"/supabase/migrations/*.sql; do
  echo "    $(basename "$f")"
  "${PSQL[@]}" -d sgd_test -f "$f"
done

echo ">>> Cargando seed.sql y seed_demo.sql (dos veces: deben ser idempotentes)"
for i in 1 2; do
  "${PSQL[@]}" -d sgd_test -f "$RAIZ/supabase/seed.sql"
  "${PSQL[@]}" -d sgd_test -f "$RAIZ/supabase/seed_demo.sql"
done

echo ">>> Pruebas de reglas de negocio"
"$PG_BIN/psql" -X -h localhost -p "$PUERTO" -U postgres -d sgd_test -v ON_ERROR_STOP=1 \
  -f "$RAIZ/supabase/tests/pruebas_reglas.sql" 2>&1 | grep -E "OK |FALLO|ERROR|pasaron" || true
"${PSQL[@]}" -d sgd_test -f "$RAIZ/supabase/tests/pruebas_reglas.sql" >"$TMP/pruebas.log" 2>&1 \
  || { echo "!!! Las pruebas de reglas fallaron:"; grep -E "ERROR|FALLO" "$TMP/pruebas.log" | head -5; exit 1; }

echo ">>> Concurrencia de consecutivos (RN-AC-08): 40 sesiones en paralelo"
for i in $(seq 1 40); do
  "${PSQL[@]}" -d sgd_test -c "select fn_siguiente_consecutivo('INT', 2099)" >/dev/null &
done
wait
RES=$("${PSQL[@]}" -d sgd_test -At -c "select ultimo from contador_consecutivo where tipo='INT' and anio=2099")
if [ "$RES" = "40" ]; then
  echo "OK  40 consecutivos únicos y sin saltos"
else
  echo "!!! Consecutivos inesperados: $RES"; exit 1
fi

echo ">>> Todo correcto"
