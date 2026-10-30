#!/usr/bin/env bash
# =============================================================================
#  Arma un solo SQL para instalar la base del SGD en un proyecto Supabase NUEVO
#  (pegar en Supabase → SQL Editor → Run). Une, en orden:
#    1. todas las migraciones de supabase/migrations/
#    2. seed.sql (parámetros, plantillas, perfiles y permisos)
#  Los datos de demostración (seed_demo.sql) van aparte y son opcionales.
#
#  Uso (desde database/):  ./scripts/armar_instalacion.sh
#  Salida: supabase/instalacion/01_estructura_y_datos_base.sql
#          supabase/instalacion/02_datos_demo_opcional.sql
# =============================================================================
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
SALIDA="$RAIZ/supabase/instalacion"
mkdir -p "$SALIDA"

BASE="$SALIDA/01_estructura_y_datos_base.sql"
{
  echo "-- SGD · Archivo Central — instalación en un proyecto Supabase NUEVO (vacío)."
  echo "-- Generado con database/scripts/armar_instalacion.sh el $(date +%Y-%m-%d). No editar a mano."
  echo "-- Ejecutar UNA sola vez en Supabase → SQL Editor. Contiene todas las migraciones y seed.sql."
  echo
  for f in "$RAIZ"/supabase/migrations/*.sql; do
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
  cat "$RAIZ/supabase/seed.sql"
} > "$BASE"

DEMO="$SALIDA/02_datos_demo_opcional.sql"
{
  echo "-- SGD · Datos de DEMOSTRACIÓN (ficticios). Opcional: solo para un proyecto de pruebas."
  echo "-- Ejecutar DESPUÉS de 01_estructura_y_datos_base.sql. Nunca en producción."
  echo
  cat "$RAIZ/supabase/seed_demo.sql"
} > "$DEMO"

echo "Listo:"
echo "  $BASE ($(wc -l < "$BASE") líneas)"
echo "  $DEMO ($(wc -l < "$DEMO") líneas)"
