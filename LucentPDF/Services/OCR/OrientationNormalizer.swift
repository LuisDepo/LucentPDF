import CoreGraphics
import Foundation
import Vision

/// Corrige la orientación cardinal de una página escaneada (0°, 90°, 180°, 270°).
///
/// Estrategia: sobre una copia reducida de la imagen se ejecuta un
/// reconocimiento de texto rápido con Vision en las cuatro orientaciones y se
/// elige aquella en la que se reconoce más texto con mayor confianza. Esto
/// resuelve de forma fiable el caso habitual de páginas escaneadas giradas o
/// invertidas. La corrección de inclinaciones finas (deskew de pocos grados) se
/// documenta como mejora futura.
struct OrientationNormalizer {

    private let log = AppLog.shared

    /// Devuelve la imagen reorientada y los grados de rotación aplicados.
    func normalize(_ image: CGImage, languages: [String]) -> (image: CGImage, rotation: Int) {
        let preview = ImageUtilities.downscaled(image, maxDimension: 1100)

        var bestRotation = 0
        var bestScore = score(of: preview, languages: languages)

        for rotation in [90, 180, 270] {
            let rotated = ImageUtilities.rotate(preview, degrees: rotation)
            let candidateScore = score(of: rotated, languages: languages)
            // Margen del 15 %: solo se rota si la mejora es clara y no ambigua.
            if candidateScore > bestScore * 1.15 {
                bestScore = candidateScore
                bestRotation = rotation
            }
        }

        guard bestRotation != 0 else { return (image, 0) }
        log.debug("Orientación corregida en \(bestRotation)°.")
        return (ImageUtilities.rotate(image, degrees: bestRotation), bestRotation)
    }

    /// Puntúa cuánto texto legible contiene una imagen (reconocimiento rápido).
    private func score(of image: CGImage, languages: [String]) -> Double {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        request.recognitionLanguages = languages

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        guard (try? handler.perform([request])) != nil else { return 0 }

        var total = 0.0
        for observation in request.results ?? [] {
            guard let candidate = observation.topCandidates(1).first else { continue }
            total += Double(candidate.string.count) * Double(candidate.confidence)
        }
        return total
    }
}
