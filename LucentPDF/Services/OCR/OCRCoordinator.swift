import CoreGraphics
import Foundation

/// Resultado de una llamada al coordinador, incluyendo qué motores intervinieron.
struct OCRRecognitionResult {
    let page: OCRPageResult
    let enginesAttempted: [OCREngineKind]
}

/// Orquesta la **arquitectura de OCR por capas**.
///
/// - Capa 1 (primaria): Apple Vision. Rápida, nativa, muy precisa.
/// - Capa 2 (respaldo): Tesseract embebido. Se usa cuando Vision falla o
///   devuelve un resultado de baja calidad (poca confianza o sin palabras).
///
/// Cuando ambos motores producen resultado, se elige el de mayor `qualityScore`.
/// Si Tesseract no está disponible, el coordinador trabaja solo con Vision sin
/// degradar la estabilidad de la app.
final class OCRCoordinator {

    /// Umbral de confianza media por debajo del cual se intenta el respaldo.
    private let confidenceThreshold = 0.55

    private let primary: OCREngine
    private let fallback: OCREngine?
    private let visionLanguages: [String]
    private let tesseractLanguages: [String]
    private let log = AppLog.shared

    init(options: ProcessingOptions) {
        self.primary = VisionOCREngine()
        self.visionLanguages = options.visionLanguages
        self.tesseractLanguages = options.tesseractLanguages

        if options.enableTesseractFallback {
            let tesseract = TesseractOCREngine()
            self.fallback = tesseract.isAvailable ? tesseract : nil
        } else {
            self.fallback = nil
        }
    }

    /// `true` si el motor de respaldo está realmente disponible en este equipo.
    var fallbackAvailable: Bool { fallback != nil }

    /// Reconoce el texto de una página, aplicando la lógica por capas.
    func recognize(image: CGImage) -> OCRRecognitionResult {
        var attempted: [OCREngineKind] = []
        var primaryResult: OCRPageResult?

        // --- Capa 1: Apple Vision ---
        attempted.append(primary.kind)
        do {
            let result = try primary.recognize(image: image, languages: visionLanguages)
            primaryResult = result
            if result.wordCount > 0, result.meanConfidence >= confidenceThreshold {
                return OCRRecognitionResult(page: result, enginesAttempted: attempted)
            }
        } catch {
            log.warning("Motor primario (Vision) falló: \(error.localizedDescription)")
        }

        // --- Capa 2: Tesseract (respaldo) ---
        if let fallback {
            attempted.append(fallback.kind)
            do {
                let fallbackResult = try fallback.recognize(
                    image: image, languages: tesseractLanguages)
                if let primaryResult,
                   primaryResult.qualityScore >= fallbackResult.qualityScore {
                    return OCRRecognitionResult(
                        page: primaryResult, enginesAttempted: attempted)
                }
                return OCRRecognitionResult(
                    page: fallbackResult, enginesAttempted: attempted)
            } catch {
                log.warning("Motor de respaldo (Tesseract) falló: \(error.localizedDescription)")
            }
        }

        // Devolver lo que haya producido el primario, aunque sea pobre.
        if let primaryResult {
            return OCRRecognitionResult(page: primaryResult, enginesAttempted: attempted)
        }
        return OCRRecognitionResult(page: .empty, enginesAttempted: attempted)
    }
}
