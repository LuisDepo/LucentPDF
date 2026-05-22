# Decisiones técnicas — LucentPDF

Documento breve que justifica las decisiones de arquitectura del proyecto.

---

## 1. Stack elegido

| Capa | Tecnología | Motivo |
|------|------------|--------|
| Lenguaje | **Swift 5.9** | Nativo de la plataforma, seguro y de alto rendimiento. |
| Interfaz | **SwiftUI** | UI declarativa nativa, light/dark mode automático, sin dependencias. |
| PDF | **PDFKit + Core Graphics** | Frameworks del sistema; lectura, rasterizado y escritura de PDF sin librerías externas. |
| OCR | **Vision + Tesseract** | Arquitectura por capas (ver §2). |
| Actualización | **Sparkle 2** | Estándar de facto para apps macOS fuera de la App Store. |
| Proyecto | **XcodeGen** | El proyecto se define en `project.yml` (texto, versionable y sin conflictos de merge). |
| Empaquetado | **create-dmg / hdiutil** | Genera el instalador `.dmg`. |
| CI | **GitHub Actions (runners macOS)** | Compila y empaqueta en la nube, gratis para repos públicos. |

La app es **100 % nativa de macOS**, no es una web envuelta. Es no-sandboxed
porque se distribuye fuera de la App Store: así accede sin fricción a las
carpetas que elige el usuario y ejecuta el binario auxiliar de Tesseract.

## 2. Motor OCR elegido y fallback

Se implementa una **arquitectura de OCR por capas** mediante el protocolo
`OCREngine` y el orquestador `OCRCoordinator`:

- **Capa 1 — primaria: Apple Vision** (`VNRecognizeTextRequest`, nivel
  `.accurate`). Justificación: es nativo (cero dependencias, cero terminal),
  está acelerado por hardware, mejora con cada versión de macOS, tiene
  excelente precisión en documentos escaneados y soporta español e inglés de
  forma nativa.
- **Capa 2 — respaldo: Tesseract** embebido en el bundle. Se activa cuando
  Vision falla o devuelve un resultado de baja calidad (poca confianza media o
  sin palabras). Aporta un segundo criterio independiente y robustez ante
  documentos difíciles.

Cuando ambos motores producen resultado, se elige el de mayor puntuación de
calidad (`qualityScore`, combina nº de palabras y confianza). Si Tesseract no
está disponible, el sistema degrada con elegancia y trabaja solo con Vision.

**Sobre "100 % de lectura OCR":** ningún motor de OCR garantiza un 100 % real
de acierto. La arquitectura por capas, los 300 ppp de rasterizado por defecto,
la corrección de orientación y la selección del mejor resultado **maximizan**
la precisión, que es lo técnicamente honesto y alcanzable.

**Encabezados y pies:** `HeaderFooterDetector` clasifica cada bloque por su
posición vertical. El usuario puede activar la omisión de encabezados y pies en
Ajustes (con franjas configurables); esos bloques no se incrustan en la capa de
texto buscable, evitando que las búsquedas tropiecen con números de página.

**Texto digital:** `PDFTextDetector` detecta páginas que ya tienen texto
seleccionable y las copia tal cual (sin reprocesar), preservando su calidad.

## 3. Encapsulado de dependencias sin exponer terminal

- **Vision, PDFKit, Core Graphics, Sparkle** son frameworks: se enlazan en el
  binario, no hay nada que instalar.
- **Tesseract** se empaqueta dentro del propio `.app`
  (`Contents/Resources/Tesseract/`): el binario, sus librerías dinámicas
  (reubicadas con `dylibbundler` y rutas `@loader_path`) y los datos de idioma
  (`spa`, `eng`, `osd`). Lo hace el script `scripts/bundle_tesseract.sh`
  durante el build.
- La app invoca ese binario mediante `Process`, de forma **silenciosa**: el
  usuario final nunca ve una terminal ni instala Homebrew ni dependencia
  alguna. Todo viaja dentro del DMG.

## 4. Estrategia para lotes grandes

- **Procesamiento en streaming**: se trata un archivo y una página a la vez; la
  página se escribe de inmediato en el PDF de salida (`PDFAssembler` mantiene un
  único `CGContext` volcando a disco) y su imagen en memoria se libera. El
  consumo de memoria **no crece** con el tamaño del lote.
- **Segundo plano**: el pipeline corre en una `Task.detached`; la interfaz
  nunca se congela y el progreso se publica al hilo principal.
- **Cancelable**: se comprueba la cancelación en los límites de página.
- **Tolerante a fallos**: si un archivo falla se registra y se continúa; el PDF
  final se genera con los archivos correctos y se escribe un reporte de
  incidencias junto a él.

## 5. Estrategia de combinación de PDF

Orden por defecto **`pathThenName`**: ruta relativa completa respecto a la
carpeta raíz y, dentro de cada carpeta, nombre de archivo. La comparación es
"localizada y number-aware" (`cap2` antes que `cap10`). El orden es **estable y
reproducible** entre ejecuciones porque la ruta relativa es única y cada
comparación incluye un desempate determinista.

El usuario puede elegir también orden por **nombre** o por **fecha de
modificación**. La regla activa se explica en la propia interfaz (pantalla de
revisión, con ayuda contextual).

## 6. Estrategia de actualizaciones

Auto-actualización real con **Sparkle 2**:

- Botón "Buscar actualizaciones" en el menú de la app y en Ajustes.
- Sparkle descarga el *appcast* (`SUFeedURL` en `Info.plist`), compara
  versiones y aplica la actualización descargando el nuevo DMG.
- El feed se sirve gratis desde **GitHub Pages**; las versiones se publican como
  **GitHub Releases**.
- Pendiente de configuración real (placeholders aislados y documentados en
  `DISTRIBUCION.md`): la clave pública EdDSA (`SUPublicEDKey`) y la URL final
  del feed. Mientras tanto la comprobación se ejecuta pero no instala.

## 7. Limitaciones reales y mejoras futuras

**Limitaciones actuales:**
- El OCR no garantiza un 100 % literal de acierto (ver §2).
- La corrección de orientación es **cardinal** (0/90/180/270°); no corrige
  inclinaciones finas (deskew de pocos grados).
- El binario embebido de Tesseract se compila para **Apple Silicon**; en Macs
  Intel el respaldo no estará disponible y se usará solo Vision (que sí es
  universal).
- El build de coste cero **no está notarizado**: la primera apertura muestra el
  aviso de Gatekeeper (se resuelve con clic derecho → Abrir).

**Mejoras futuras:**
- Deskew fino por detección de ángulo de línea base.
- Compilar Tesseract universal (arm64 + x86_64).
- Notarización automática en CI (requiere cuenta Apple Developer).
- Compresión configurable de las imágenes del PDF final.
- Previsualización de páginas en la pantalla de revisión.
- Recordar la última carpeta y permitir reanudar lotes interrumpidos.
