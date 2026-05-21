import CoreGraphics
import Foundation

/// Un bloque de texto reconocido (una línea o palabra) con su posición.
///
/// `boundingBox` está **normalizado** (0...1) con origen en la esquina
/// inferior-izquierda, igual que la convención de Apple Vision. Esto permite
/// que ambos motores (Vision y Tesseract) compartan el mismo formato.
struct OCRTextBlock {
    let text: String
    let boundingBox: CGRect
    let confidence: Double
}

/// Resultado del OCR de una página completa.
struct OCRPageResult {
    var blocks: [OCRTextBlock]
    var engine: OCREngineKind

    var wordCount: Int {
        blocks.reduce(0) { $0 + $1.text.split(separator: " ").count }
    }

    var meanConfidence: Double {
        guard !blocks.isEmpty else { return 0 }
        return blocks.reduce(0) { $0 + $1.confidence } / Double(blocks.count)
    }

    /// Puntuación de calidad usada para comparar resultados de motores distintos.
    var qualityScore: Double {
        Double(wordCount) * (0.5 + 0.5 * meanConfidence)
    }

    static let empty = OCRPageResult(blocks: [], engine: .none)
}

enum OCREngineError: LocalizedError {
    case engineUnavailable
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .engineUnavailable:
            return "El motor de OCR no está disponible."
        case .recognitionFailed(let detail):
            return "Fallo de reconocimiento: \(detail)"
        }
    }
}

/// Interfaz común de un motor de OCR. La arquitectura por capas se apoya en
/// este protocolo: el `OCRCoordinator` usa un motor primario y uno de respaldo.
protocol OCREngine {
    var kind: OCREngineKind { get }
    /// `true` si el motor puede usarse en este equipo y configuración.
    var isAvailable: Bool { get }
    /// Reconoce el texto de una imagen ya rasterizada y orientada.
    func recognize(image: CGImage, languages: [String]) throws -> OCRPageResult
}
