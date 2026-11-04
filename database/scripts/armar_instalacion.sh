#!/usr/bin/env bash
# =============================================================================
#  Arma un solo SQL para instalar la base del SGD en un PostgreSQL NUEVO (base vacía), para
#  quien no pueda correr scripts/instalar_local.sh: psql "<cadena>" -f instalacion/01_....sql
#  No crea el rol del backend ni registra sgd_migracion: para producción use instalar_local.sh.
#  Une, en orden:
#    1. todas las migraciones de migrations/
#    2. seed.sql (parámetros, plantillas, perfiles y permisos)
#  Los datos de demostración (seed_demo.sql) van aparte y son opcionales.
#
#  Uso (desde database/):  ./scripts/armar_instalacion.sh
#  Salida: instalacion/01_estructura_y_datos_base.sql
#          instalacion/02_datos_demo_opcional.sql
# =============================================================================
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
SALIDA="$RAIZ/instalacion"
mkdir -p "$SALIDA"

BASE="$SALIDA/01_estructura_y_datos_base.sql"
{
  echo "-- SGD · Archivo Central — instalación en una base PostgreSQL NUEVA (vacía)."
  echo "-- Generado con database/scripts/armar_instalacion.sh el $(date +%Y-%m-%d). No editar a mano."
  echo "-- Ejecutar UNA sola vez con psql. Contiene todas las migraciones y seed.sql."
  echo
  for f in "$RAIZ"/migrations/*.sql; do
    echo
    echo "-- ═════════════════════════════════════════════════════════════════════════════"
    echo "-- Migración: $(basename "$f")"
    echo "-- ═════════════════════════════════════════════════════════════════════════════"
    cat "$f"
    echo
  done
  echo
  echo "-- ═════════════════════════════════════════════════════════════════════════════"
  echo "-- Datos base: seed.sql"
  echo "-- ═════════════════════════════════════════════════════════════════════════════"
  cat "$RAIZ/seed.sql"
} > "$BASE"

DEMO="$SALIDA/02_datos_demo_opcional.sql"
{
  echo "-- SGD · Datos de DEMOSTRACIÓN (ficticios). Opcional: solo para una base de pruebas."
  echo "-- Ejecutar DESPUÉS de 01_estructura_y_datos_base.sql. Nunca en producción."
  echo
  cat "$RAIZ/seed_demo.sql"
} > "$DEMO"

echo "Listo:"
echo "  $BASE ($(wc -l < "$BASE") líneas)"
echo "  $DEMO ($(wc -l < "$DEMO") líneas)"
