#!/usr/bin/env bash
# =============================================================================
#  Prueba la base de datos en un PostgreSQL temporal (no toca servicios existentes).
#  1. Crea un clúster en una carpeta temporal y lo levanta en el puerto $PUERTO.
#  2. Instala la base con scripts/instalar_local.sh (migraciones, seed.sql y rol del backend) y lo
#     corre otra vez (debe ser idempotente); carga seed.sql y seed_demo.sql dos veces.
#  3. Ejecuta tests/pruebas_reglas.sql, una prueba de concurrencia de consecutivos y revisa los
#     permisos del rol del backend (lee y ejecuta funciones; no borra filas).
#  4. Apaga y borra el clúster.
#
#  Uso:  PG_BIN="/c/Program Files/PostgreSQL/18/bin" ./scripts/probar_local.sh
#        (en Linux, por ejemplo PG_BIN=/usr/lib/postgresql/18/bin)
#        Sin PostgreSQL instalado, dentro de un contenedor:  ./scripts/probar_local.sh --docker
# =============================================================================
set -euo pipefail

if [ "${1:-}" = "--docker" ]; then
  RAIZ_HOST="$(cd "$(dirname "$0")/.." && (pwd -W 2>/dev/null || pwd))"
  exec env MSYS_NO_PATHCONV=1 docker run --rm --user postgres -e PG_BIN=/usr/local/bin -e TMPDIR=/tmp     -v "$RAIZ_HOST:/database:ro" postgres:18-alpine bash /database/scripts/probar_local.sh
fi

PG_BIN="${PG_BIN:-/c/Program Files/PostgreSQL/18/bin}"
PUERTO="${PUERTO:-54329}"
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
TMP="${TMPDIR:-${TEMP:-/tmp}}/sgd_pg_$$"
export PATH="$PG_BIN:$PATH"
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

URL="postgres://postgres@localhost:$PUERTO/sgd_test"
echo ">>> Instalando con instalar_local.sh (dos veces: la segunda no debe aplicar nada)"
DATABASE_URL="$URL" SGD_BACKEND_PASSWORD=prueba-local "$RAIZ/scripts/instalar_local.sh" | grep -E "Migraciones nuevas|Base lista|!!!"
DATABASE_URL="$URL" SGD_BACKEND_PASSWORD=prueba-local "$RAIZ/scripts/instalar_local.sh" | grep -E "Migraciones nuevas: 0" >/dev/null \
  || { echo "!!! La segunda instalación volvió a aplicar migraciones"; exit 1; }

echo ">>> Cargando seed.sql y seed_demo.sql (dos veces: deben ser idempotentes)"
for i in 1 2; do
  "${PSQL[@]}" -d sgd_test -f "$RAIZ/seed.sql"
  "${PSQL[@]}" -d sgd_test -f "$RAIZ/seed_demo.sql"
done

echo ">>> Pruebas de reglas de negocio"
"$PG_BIN/psql" -X -h localhost -p "$PUERTO" -U postgres -d sgd_test -v ON_ERROR_STOP=1 \
  -f "$RAIZ/tests/pruebas_reglas.sql" 2>&1 | grep -E "OK |FALLO|ERROR|pasaron" || true
"${PSQL[@]}" -d sgd_test -f "$RAIZ/tests/pruebas_reglas.sql" >"$TMP/pruebas.log" 2>&1 \
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

echo ">>> Permisos del rol del backend (sgd_backend)"
BACK=("$PG_BIN/psql" -X -q -h localhost -p "$PUERTO" -U sgd_backend -d sgd_test -v ON_ERROR_STOP=1)
"${BACK[@]}" -At -c "select count(*) from dependencia" >/dev/null \
  && "${BACK[@]}" -At -c "select fn_tiene_permiso(null, 'documentos.consultar')" >/dev/null \
  || { echo "!!! sgd_backend no puede leer tablas o ejecutar funciones"; exit 1; }
if "${BACK[@]}" -c "delete from parametro where false" >/dev/null 2>&1; then
  echo "!!! sgd_backend puede borrar filas (no debe: no hay borrado físico)"; exit 1
fi
echo "OK  sgd_backend lee y ejecuta funciones; no puede borrar filas"

echo ">>> Todo correcto"
