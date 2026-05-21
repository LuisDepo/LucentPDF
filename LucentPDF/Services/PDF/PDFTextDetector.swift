import Foundation
import PDFKit

/// Detecta si una página PDF ya contiene texto digital seleccionable.
///
/// Las páginas con texto digital ya son buscables: aplicarles OCR sería
/// innecesario y degradaría su calidad. Cuando el usuario activa "omitir
/// páginas con texto", esas páginas se copian al PDF final tal cual.
struct PDFTextDetector {

    /// Mínimo de caracteres alfanuméricos para considerar la página "digital".
    private let minimumMeaningfulCharacters = 24

    func hasDigitalText(_ page: PDFPage) -> Bool {
        guard let text = page.string, !text.isEmpty else { return false }
        let meaningful = text.unicodeScalars.lazy.filter {
            CharacterSet.alphanumerics.contains($0)
        }
        return meaningful.count >= minimumMeaningfulCharacters
    }
}
