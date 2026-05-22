#!/bin/bash
#
# Empaqueta el binario de Tesseract y sus librerías dentro del bundle .app.
#
# Se ejecuta en CI (o en local) DESPUÉS de compilar la app. El usuario final
# nunca ve una terminal: la app invoca este binario embebido de forma silenciosa.
# Si este script falla, la app sigue funcionando solo con Apple Vision.
#
# Uso:  ./scripts/bundle_tesseract.sh <ruta/LucentPDF.app>
#
set -euo pipefail

APP="${1:?Uso: bundle_tesseract.sh <ruta/LucentPDF.app>}"
RES="$APP/Contents/Resources/Tesseract"

echo "==> Empaquetando Tesseract en: $RES"

command -v brew >/dev/null 2>&1 || { echo "ERROR: Homebrew no disponible."; exit 1; }
brew list tesseract       >/dev/null 2>&1 || brew install tesseract
brew list tesseract-lang  >/dev/null 2>&1 || brew install tesseract-lang
command -v dylibbundler   >/dev/null 2>&1 || brew install dylibbundler

TPREFIX="$(brew --prefix tesseract)"
TBIN="$TPREFIX/bin/tesseract"
[ -x "$TBIN" ] || { echo "ERROR: binario de Tesseract no encontrado."; exit 1; }

mkdir -p "$RES/bin" "$RES/lib" "$RES/tessdata"
cp "$TBIN" "$RES/bin/tesseract"
chmod +x "$RES/bin/tesseract"

# Reubica las librerías dinámicas dentro del bundle (rutas relativas).
dylibbundler -of -b -x "$RES/bin/tesseract" -d "$RES/lib" -p "@loader_path/../lib/"

# Copia los datos de idioma: español, inglés y detección de orientación.
copied=0
for lang in spa eng osd; do
  for dir in \
      "$(brew --prefix tesseract-lang 2>/dev/null || true)/share/tessdata" \
      "$TPREFIX/share/tessdata" \
      "$(brew --prefix)/share/tessdata"; do
    if [ -f "$dir/$lang.traineddata" ]; then
      cp "$dir/$lang.traineddata" "$RES/tessdata/"
      copied=$((copied + 1))
      break
    fi
  done
done
echo "==> Datos de idioma copiados: $copied"

[ -f "$RES/tessdata/spa.traineddata" ] || echo "AVISO: falta spa.traineddata"
[ -f "$RES/tessdata/eng.traineddata" ] || echo "AVISO: falta eng.traineddata"

echo "==> Tesseract empaquetado correctamente."
