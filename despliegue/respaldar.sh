#!/usr/bin/env bash
# =============================================================================
#  Respaldo del SGD: base de datos y archivos JUNTOS (la base referencia cada archivo por su id).
#  Deja en $DESTINO (por defecto ./respaldos):
#    sgd_<fecha>.dump          pg_dump en formato custom (se restaura con pg_restore)
#    archivos_<fecha>.tgz      el volumen archivos_sgd completo
#  y borra los respaldos con más de $DIAS días (por defecto 30).
#
#  Uso (desde despliegue/, con los contenedores arriba):   ./respaldar.sh
#  Programado (cron del servidor, todos los días a las 2:00):
#    0 2 * * * cd /opt/sgd/despliegue && ./respaldar.sh >> respaldos/respaldo.log 2>&1
#  Copie además $DESTINO fuera del servidor (otro disco, NAS o almacenamiento institucional).
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"
DESTINO="${DESTINO:-./respaldos}"
DIAS="${DIAS:-30}"
FECHA="$(date +%F_%H%M)"
mkdir -p "$DESTINO"
DESTINO="$(cd "$DESTINO" && pwd)"

echo ">>> $(date '+%F %T') Respaldando la base"
docker compose exec -T db pg_dump -U postgres -d sgd -Fc > "$DESTINO/sgd_$FECHA.dump.parcial"
mv "$DESTINO/sgd_$FECHA.dump.parcial" "$DESTINO/sgd_$FECHA.dump"

echo ">>> Respaldando los archivos"
# El contenedor del backend monta el volumen en /data/archivos; se lee desde ahí, sin detenerlo.
docker compose exec -T backend tar czf - -C /data/archivos . > "$DESTINO/archivos_$FECHA.tgz.parcial"
mv "$DESTINO/archivos_$FECHA.tgz.parcial" "$DESTINO/archivos_$FECHA.tgz"

find "$DESTINO" -maxdepth 1 \( -name 'sgd_*.dump' -o -name 'archivos_*.tgz' \) -mtime +"$DIAS" -delete
echo ">>> Listo: $DESTINO/sgd_$FECHA.dump y $DESTINO/archivos_$FECHA.tgz"
