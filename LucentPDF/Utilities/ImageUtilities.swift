import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Utilidades de bajo nivel para manipular imágenes `CGImage`.
enum ImageUtilities {

    enum ImageError: LocalizedError {
        case pngEncodingFailed
        var errorDescription: String? { "No se pudo codificar la imagen temporal." }
    }

    /// Escribe un `CGImage` como PNG en disco (usado para alimentar a Tesseract).
    static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
        ) else {
            throw ImageError.pngEncodingFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ImageError.pngEncodingFailed
        }
    }

    /// Rota un `CGImage` en múltiplos de 90°. `degrees` puede ser 0, 90, 180 o 270.
    static func rotate(_ image: CGImage, degrees: Int) -> CGImage {
        let normalized = ((degrees % 360) + 360) % 360
        guard normalized != 0 else { return image }

        let width = image.width
        let height = image.height
        let swapsAxes = (normalized == 90 || normalized == 270)
        let outWidth = swapsAxes ? height : width
        let outHeight = swapsAxes ? width : height

        guard let context = CGContext(
            data: nil,
            width: outWidth,
            height: outHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }

        context.translateBy(x: CGFloat(outWidth) / 2, y: CGFloat(outHeight) / 2)
        context.rotate(by: -CGFloat(normalized) * .pi / 180)
        context.translateBy(x: -CGFloat(width) / 2, y: -CGFloat(height) / 2)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        return context.makeImage() ?? image
    }

    /// Genera una copia reducida (para análisis rápidos como la orientación).
    static func downscaled(_ image: CGImage, maxDimension: Int) -> CGImage {
        let width = image.width
        let height = image.height
        let largest = max(width, height)
        guard largest > maxDimension else { return image }

        let scale = Double(maxDimension) / Double(largest)
        let outWidth = max(1, Int(Double(width) * scale))
        let outHeight = max(1, Int(Double(height) * scale))

        guard let context = CGContext(
            data: nil,
            width: outWidth,
            height: outHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: outWidth, height: outHeight))
        return context.makeImage() ?? image
    }
}
