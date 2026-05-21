import CoreGraphics
import Foundation

/// Convierte una página PDF en una imagen de mapa de bits para alimentar al OCR.
struct PDFRasterizer {

    /// Rasteriza una página a la resolución indicada (en puntos por pulgada).
    /// Tiene en cuenta el `cropBox` y la rotación intrínseca de la página.
    func rasterize(_ page: CGPDFPage, dpi: Int) -> CGImage? {
        let cropBox = page.getBoxRect(.cropBox)
        let rotation = page.rotationAngle

        var logicalWidth = cropBox.width
        var logicalHeight = cropBox.height
        if abs(rotation) == 90 || abs(rotation) == 270 {
            swap(&logicalWidth, &logicalHeight)
        }
        guard logicalWidth > 0, logicalHeight > 0 else { return nil }

        let scale = CGFloat(dpi) / 72.0
        let pixelWidth = Int((logicalWidth * scale).rounded())
        let pixelHeight = Int((logicalHeight * scale).rounded())
        // Salvaguarda contra páginas absurdamente grandes (evita agotar memoria).
        guard pixelWidth > 0, pixelHeight > 0,
              pixelWidth <= 20_000, pixelHeight <= 20_000 else { return nil }

        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            return nil
        }

        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        context.interpolationQuality = .high

        context.scaleBy(x: scale, y: scale)
        let transform = page.getDrawingTransform(
            .cropBox,
            rect: CGRect(x: 0, y: 0, width: logicalWidth, height: logicalHeight),
            rotate: 0,
            preserveAspectRatio: true
        )
        context.concatenate(transform)
        context.drawPDFPage(page)

        return context.makeImage()
    }
}
