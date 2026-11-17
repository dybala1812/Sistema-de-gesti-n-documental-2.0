#!/usr/bin/env bash
# =============================================================================
#  Corre las pruebas de aceptación F-05 contra el sistema de despliegue/docker-compose.yml:
#  imagen real del backend + PostgreSQL 18 en un proyecto aparte (sgdf05) que se BORRA al final.
#
#  Uso (desde la raíz del repositorio, con Docker y Node 24):
#    bash backned_sistema_gestion_documental/tests/aceptacion/correr_f05.sh [salida.json]
#  RENDIMIENTO=1 agrega la prueba con 50.000 documentos. SIN_BUILD=1 reutiliza la imagen sgd-backend:latest.
# =============================================================================
set -euo pipefail
export MSYS_NO_PATHCONV=1
RAIZ="$(git rev-parse --show-toplevel)"
SALIDA="${1:-}"
cd "$RAIZ/despliegue"

export COMPOSE_PROJECT_NAME=sgdf05
export POSTGRES_PASSWORD="$(openssl rand -hex 16)" SGD_BACKEND_PASSWORD="$(openssl rand -hex 16)" N8N_SERVICE_TOKEN="$(openssl rand -hex 16)"
export NOVA_PUERTO="${NOVA_PUERTO:-8010}" NOVA_API_URL="http://host.docker.internal:${NOVA_PUERTO:-8010}"
export ALLOWED_ORIGINS=http://localhost:5173 PUERTO_BACKEND=127.0.0.1:3011

limpiar() { [ "${CONSERVAR:-0}" = "1" ] && return 0; docker compose down -v >/dev/null 2>&1 || true; }
trap limpiar EXIT

if [ "${SIN_BUILD:-0}" != "1" ]; then docker compose build backend; fi
docker compose up -d --no-build db migraciones backend
for _ in $(seq 1 60); do
  curl -s -m 3 http://127.0.0.1:3011/api/salud | grep -q '"bd":true' && break
  sleep 2
done
docker compose cp "$RAIZ/database/seed_demo.sql" db:/tmp/seed_demo.sql
docker compose exec -T db psql -U postgres -d sgd -q -f /tmp/seed_demo.sql

BACKEND=http://127.0.0.1:3011 SALIDA="$SALIDA" \
SQL_CMD="docker compose exec -T db psql -U postgres -d sgd -At -v ON_ERROR_STOP=1 -c" \
  node "$RAIZ/backned_sistema_gestion_documental/tests/aceptacion/f05_api.mjs"
