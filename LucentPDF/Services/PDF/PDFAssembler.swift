import CoreGraphics
import CoreText
import Foundation

/// Escribe el PDF final **en streaming**, página a página, directamente a disco.
///
/// Mantener un único `CGContext` de PDF y volcar cada página según se procesa
/// evita acumular todas las imágenes en memoria: el consumo se mantiene acotado
/// aunque el lote tenga miles de páginas.
///
/// Cada página se escribe de una de dos formas:
/// - `appendOriginalPage`: copia vectorial fiel de la página de origen (para
///   páginas que ya tenían texto digital).
/// - `appendImagePage`: la imagen de la página escaneada más una **capa de
///   texto invisible** superpuesta, que la hace buscable y seleccionable.
final class PDFAssembler {

    enum AssemblerError: LocalizedError {
        case cannotCreateOutput
        var errorDescription: String? { "No se pudo crear el archivo PDF de salida." }
    }

    private let context: CGContext
    private(set) var pageCount = 0

    init(outputURL: URL, title: String) throws {
        guard let consumer = CGDataConsumer(url: outputURL as CFURL) else {
            throw AssemblerError.cannotCreateOutput
        }
        var defaultBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        let auxiliaryInfo: [String: Any] = [
            kCGPDFContextCreator as String: "LucentPDF",
            kCGPDFContextTitle as String: title,
        ]
        guard let context = CGContext(
            consumer: consumer,
            mediaBox: &defaultBox,
            auxiliaryInfo as CFDictionary
        ) else {
            throw AssemblerError.cannotCreateOutput
        }
        self.context = context
    }

    /// Copia una página original tal cual, preservando texto y vectores.
    func appendOriginalPage(_ page: CGPDFPage) {
        let mediaBox = page.getBoxRect(.mediaBox)
        let rotation = page.rotationAngle

        var width = mediaBox.width
        var height = mediaBox.height
        if abs(rotation) == 90 || abs(rotation) == 270 {
            swap(&width, &height)
        }
        let outputBox = CGRect(x: 0, y: 0, width: width, height: height)

        context.beginPDFPage(pageInfo(mediaBox: outputBox))
        context.saveGState()
        let transform = page.getDrawingTransform(
            .mediaBox, rect: outputBox, rotate: 0, preserveAspectRatio: true)
        context.concatenate(transform)
        context.drawPDFPage(page)
        context.restoreGState()
        context.endPDFPage()
        pageCount += 1
    }

    /// Añade una página rasterizada con su capa de texto buscable invisible.
    /// `pageSize` está en puntos PDF (1/72").
    func appendImagePage(image: CGImage, size pageSize: CGSize, textBlocks: [OCRTextBlock]) {
        let box = CGRect(origin: .zero, size: pageSize)
        context.beginPDFPage(pageInfo(mediaBox: box))

        // Capa visible: imagen de la página.
        context.draw(image, in: box)

        // Capa invisible: texto buscable alineado con las palabras de la imagen.
        drawSearchableTextLayer(textBlocks, pageSize: pageSize)

        context.endPDFPage()
        pageCount += 1
    }

    func finish() {
        context.closePDF()
    }

    // MARK: - Privado

    private func drawSearchableTextLayer(_ blocks: [OCRTextBlock], pageSize: CGSize) {
        guard !blocks.isEmpty else { return }

        context.saveGState()
        // Modo de dibujo de texto invisible: las letras se incrustan en el flujo
        // del PDF (búsqueda/selección) pero no se pintan sobre la imagen.
        context.setTextDrawingMode(.invisible)

        for block in blocks {
            let text = block.text
            guard !text.isEmpty else { continue }

            let bb = block.boundingBox
            let rect = CGRect(
                x: bb.minX * pageSize.width,
                y: bb.minY * pageSize.height,
                width: bb.width * pageSize.width,
                height: bb.height * pageSize.height)
            guard rect.width > 1, rect.height > 1 else { continue }

            let fontSize = max(2, rect.height * 0.85)
            let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
            let fontKey = NSAttributedString.Key(kCTFontAttributeName as String)
            let attributed = NSAttributedString(string: text, attributes: [fontKey: font])
            let line = CTLineCreateWithAttributedString(attributed as CFAttributedString)

            let textWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            guard textWidth > 0 else { continue }

            // Escala horizontal para que el texto invisible cubra el ancho de la
            // palabra: mejora la precisión de selección y resaltado.
            let horizontalScale = rect.width / textWidth
            context.textMatrix = CGAffineTransform(scaleX: horizontalScale, y: 1)
            context.textPosition = CGPoint(
                x: rect.minX,
                y: rect.minY + rect.height * 0.18)
            CTLineDraw(line, context)
        }

        context.restoreGState()
    }

    /// Construye el diccionario de página con su `MediaBox`.
    private func pageInfo(mediaBox: CGRect) -> CFDictionary {
        [kCGPDFContextMediaBox as String: boxData(mediaBox)] as CFDictionary
    }

    /// Empaqueta un `CGRect` como `CFData` (formato exigido por `kCGPDFContextMediaBox`).
    private func boxData(_ rect: CGRect) -> CFData {
        var value = rect
        let data = Data(bytes: &value, count: MemoryLayout<CGRect>.size)
        return data as CFData
    }
}
