#!/bin/bash
#
# Genera/actualiza el appcast.xml de Sparkle a partir de los .dmg de una carpeta.
#
# Requiere las herramientas de Sparkle (incluyen `generate_appcast`) y la clave
# privada EdDSA en el llavero. Ver docs/DISTRIBUCION.md para la configuración.
#
# Uso:  ./scripts/generate_appcast.sh <carpeta-con-dmgs>
#
set -euo pipefail

RELEASES_DIR="${1:?Uso: generate_appcast.sh <carpeta-con-dmgs>}"

if ! command -v generate_appcast >/dev/null 2>&1; then
  cat <<'EOF'
ERROR: no se encontró `generate_appcast`.

Descarga las herramientas de Sparkle desde:
  https://github.com/sparkle-project/Sparkle/releases
y añade su carpeta `bin` al PATH. Consulta docs/DISTRIBUCION.md.
EOF
  exit 1
fi

echo "==> Generando appcast.xml en: $RELEASES_DIR"
generate_appcast "$RELEASES_DIR"
echo "==> Listo. Publica appcast.xml en la URL del feed (SUFeedURL)."
