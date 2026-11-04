#!/usr/bin/env bash
# =============================================================================
#  Arma la rama "despliegue-backend": lo que se entrega a producción, SIN NOVA_FT,
#  ia_contexto, skills ni flujos de trabajo. Contiene solo:
#    backned_sistema_gestion_documental/   backend (Dockerfile)
#    database/                              migraciones, seed e instalador
#    despliegue/                            docker-compose con PostgreSQL propio y respaldos
#    README_DEPLOY.md                       guía de despliegue
#  Cada ejecución agrega un commit a esa rama con la foto de <ref> (por defecto HEAD).
#  Solo toma lo que está en commits: primero haga commit de los cambios.
#
#  Uso (desde la raíz del repo):  ./scripts/armar_rama_despliegue.sh [ref]
#  Subir:                          git push origin despliegue-backend
# =============================================================================
set -euo pipefail
REF="${1:-HEAD}"
RAMA="despliegue-backend"
cd "$(git rev-parse --show-toplevel)"
SHA="$(git rev-parse --short "$REF")"
DIR="$(mktemp -d)"
limpiar() { git worktree remove --force "$DIR" >/dev/null 2>&1 || rm -rf "$DIR"; }
trap limpiar EXIT

if git show-ref --verify --quiet "refs/heads/$RAMA"; then
  git worktree add -q "$DIR" "$RAMA"
else
  git worktree add -q --orphan -b "$RAMA" "$DIR"
fi

find "$DIR" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
git archive "$REF" backned_sistema_gestion_documental database despliegue README_DEPLOY.md | tar -x -C "$DIR"
cat > "$DIR/README.md" <<TXT
# SGD · Módulo Archivo Central — despliegue del backend

Rama generada con \`scripts/armar_rama_despliegue.sh\` desde el commit \`$SHA\` del repositorio principal.
No se edita a mano: los cambios se hacen en el repositorio principal y se vuelve a generar.

Contiene solo el backend, la base de datos y la configuración de despliegue (sin el frontend de NOVA).
Instrucciones: [README_DEPLOY.md](README_DEPLOY.md).
TXT

git -C "$DIR" add -A
if git -C "$DIR" diff --cached --quiet; then
  echo "Sin cambios respecto a la última versión de $RAMA"
else
  git -C "$DIR" commit -q -m "chore(despliegue): backend y base de datos desde $SHA${TRAILER:+

$TRAILER}"
  echo "Rama $RAMA actualizada desde $SHA ($(git rev-parse --short "$RAMA"))"
fi
