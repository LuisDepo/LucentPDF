# Distribución — LucentPDF

Cómo compilar la app, crear el instalador `.dmg` y publicar versiones.

---

## Opción A — Compilar en GitHub (recomendada, sin tocar una terminal)

El repositorio incluye un *workflow* que compila la app en los Mac de GitHub.

1. Entra en el repositorio en GitHub → pestaña **Actions**.
2. Elige **Build LucentPDF** en la lista de la izquierda.
3. Pulsa **Run workflow** y confirma.
4. Al terminar (unos minutos), abre la ejecución y descarga el artefacto
   **`LucentPDF-dmg`**. Dentro está `LucentPDF.dmg`.

Para publicar una versión con página de descarga: crea una **etiqueta** con el
formato `vX.Y.Z` (por ejemplo `v1.0.0`). El workflow generará automáticamente
una **Release** con el `.dmg` adjunto.

> Requisito de coste cero: el repositorio debe ser **público** para que los
> runners de macOS sean gratuitos e ilimitados.

## Opción B — Compilar en tu propio Mac

Necesitas macOS con **Xcode** instalado (gratis en la Mac App Store).

```bash
# 1. Generar y abrir el proyecto en Xcode
./scripts/dev_setup.sh

# 2. (o por línea de comandos) compilar + empaquetar Tesseract + crear DMG
xcodegen generate
xcodebuild -project LucentPDF.xcodeproj -scheme LucentPDF \
  -configuration Release -derivedDataPath build/DerivedData \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO clean build
APP=build/DerivedData/Build/Products/Release/LucentPDF.app
./scripts/bundle_tesseract.sh "$APP"
codesign --force --deep --sign - "$APP"
./scripts/build_dmg.sh "$APP" build/LucentPDF.dmg
```

## Instalación para el usuario final

1. Abrir `LucentPDF.dmg` y arrastrar **LucentPDF** a la carpeta Aplicaciones.
2. **Primera apertura** (build sin notarizar): clic derecho sobre la app →
   **Abrir** → **Abrir**. Solo es necesario una vez. macOS lo recordará.

---

## Firma y notarización (opcional — para una experiencia sin avisos)

El build de coste cero usa **firma ad-hoc** y no está notarizado, por lo que
aparece el aviso de Gatekeeper en la primera apertura. Para eliminarlo hace
falta una cuenta **Apple Developer Program** (99 USD/año).

### Pasos una vez se disponga de la cuenta

1. **Certificado**: en Xcode → Settings → Accounts, crear un certificado
   *Developer ID Application*.
2. **`project.yml`**: rellenar `DEVELOPMENT_TEAM` con el Team ID y cambiar
   `CODE_SIGN_IDENTITY` a `Developer ID Application`.
3. **Hardened Runtime**: poner `ENABLE_HARDENED_RUNTIME: YES` (requerido para
   notarizar).
4. **Notarización** (tras compilar y crear el DMG):
   ```bash
   xcrun notarytool submit build/LucentPDF.dmg \
     --apple-id "TU_APPLE_ID" --team-id "TU_TEAM_ID" \
     --password "CONTRASEÑA_ESPECÍFICA_DE_APP" --wait
   xcrun stapler staple build/LucentPDF.dmg
   ```
5. **Automatizar en CI**: guardar como *secrets* del repositorio el certificado
   `.p12` (en base64), su contraseña y una *App Store Connect API Key*, y
   añadir al workflow los pasos de importación del certificado y `notarytool`.

> Todos los valores sensibles son **placeholders aislados**: `DEVELOPMENT_TEAM`
> vacío en `project.yml` y los *secrets* no se versionan (ver `.gitignore`).

---

## Auto-actualización (Sparkle)

La app ya integra Sparkle 2. Para que las actualizaciones funcionen en
producción hay que completar dos placeholders.

### 1. Generar las claves EdDSA (una sola vez)

Descarga las herramientas de Sparkle desde sus *releases* en GitHub y ejecuta:

```bash
./bin/generate_keys
```

Guarda la **clave privada** de forma segura (queda en el llavero; nunca se
versiona). Copia la **clave pública** que imprime.

### 2. Configurar la app

- En `LucentPDF/Resources/Info.plist`, sustituir `SUPublicEDKey` por la clave
  pública generada.
- En el mismo archivo, ajustar `SUFeedURL` a la URL real del feed, por ejemplo:
  `https://TU_USUARIO.github.io/lucentpdf/appcast.xml`.

### 3. Publicar el appcast

1. Activar **GitHub Pages** para el repositorio (rama `main`, carpeta `/docs` o
   raíz).
2. Por cada versión nueva: colocar los `.dmg` en una carpeta y ejecutar
   ```bash
   ./scripts/generate_appcast.sh <carpeta-con-dmgs>
   ```
   Esto firma cada versión con la clave privada y genera `appcast.xml`.
3. Publicar `appcast.xml` (y los `.dmg`) en la URL del feed.

A partir de ahí, el botón "Buscar actualizaciones" detectará, descargará e
instalará las versiones nuevas.

---

## Crear una versión nueva (resumen)

1. Subir el número de versión: `MARKETING_VERSION` y `CURRENT_PROJECT_VERSION`
   en `project.yml`.
2. `git commit` y crear la etiqueta: `git tag v1.0.1 && git push --tags`.
3. GitHub Actions compila y crea la Release con el `.dmg`.
4. (Con Sparkle configurado) regenerar y publicar `appcast.xml`.
