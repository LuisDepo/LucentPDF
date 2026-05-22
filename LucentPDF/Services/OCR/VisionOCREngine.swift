import CoreGraphics
import Foundation
import Vision

/// Motor de OCR primario, basado en el framework Apple Vision.
///
/// Vision es nativo de macOS (no requiere binarios externos ni dependencias),
/// está acelerado por hardware, recibe mejoras con cada versión del sistema y
/// ofrece muy buena precisión en documentos escaneados en español e inglés.
/// Devuelve el texto a nivel de línea con su recuadro normalizado.
struct VisionOCREngine: OCREngine {

    let kind: OCREngineKind = .vision

    /// Vision forma parte del sistema operativo: siempre disponible en macOS 13+.
    var isAvailable: Bool { true }

    func recognize(image: CGImage, languages: [String]) throws -> OCRPageResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = languages

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw OCREngineError.recognitionFailed(error.localizedDescription)
        }

        let observations = request.results ?? []
        var blocks: [OCRTextBlock] = []
        blocks.reserveCapacity(observations.count)

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            blocks.append(OCRTextBlock(
                text: text,
                boundingBox: observation.boundingBox,
                confidence: Double(candidate.confidence)
            ))
        }

        return OCRPageResult(blocks: blocks, engine: .vision)
    }
}
