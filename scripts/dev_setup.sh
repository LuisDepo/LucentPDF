#!/bin/bash
#
# Prepara el proyecto para abrirlo en Xcode (SOLO para desarrollo en un Mac).
# El usuario final no necesita esto: descarga el .dmg ya hecho desde GitHub.
#
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "==> Instalando XcodeGen…"
  if command -v brew >/dev/null 2>&1; then
    brew install xcodegen
  else
    echo "ERROR: instala Homebrew (https://brew.sh) o XcodeGen manualmente."
    exit 1
  fi
fi

echo "==> Generando el proyecto Xcode…"
xcodegen generate

echo "==> Abriendo LucentPDF.xcodeproj en Xcode…"
open LucentPDF.xcodeproj
