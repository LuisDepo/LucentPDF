#!/bin/bash
#
# Crea el instalador .dmg a partir de una app ya compilada.
#
# Uso:  ./scripts/build_dmg.sh <ruta/LucentPDF.app> [salida.dmg]
#
set -euo pipefail

APP="${1:?Uso: build_dmg.sh <ruta/LucentPDF.app> [salida.dmg]}"
DMG="${2:-build/LucentPDF.dmg}"
ICNS="docs/assets/LucentPDF.icns"

[ -d "$APP" ] || { echo "ERROR: no existe la app: $APP"; exit 1; }
mkdir -p "$(dirname "$DMG")"
rm -f "$DMG"

make_with_create_dmg() {
  local args=(
    --volname "LucentPDF"
    --window-size 560 380
    --icon-size 110
    --icon "LucentPDF.app" 150 190
    --app-drop-link 410 190
    --hide-extension "LucentPDF.app"
  )
  [ -f "$ICNS" ] && args+=(--volicon "$ICNS")
  create-dmg "${args[@]}" "$DMG" "$APP"
}

make_with_hdiutil() {
  echo "==> Usando hdiutil (alternativa a create-dmg)"
  local staging
  staging="$(mktemp -d)"
  cp -R "$APP" "$staging/"
  ln -s /Applications "$staging/Applications"
  hdiutil create -volname "LucentPDF" -srcfolder "$staging" \
    -ov -format UDZO "$DMG"
  rm -rf "$staging"
}

if command -v create-dmg >/dev/null 2>&1; then
  make_with_create_dmg || make_with_hdiutil
else
  make_with_hdiutil
fi

echo "==> Instalador creado: $DMG"
