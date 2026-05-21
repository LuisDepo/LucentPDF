import CoreGraphics
import Foundation

/// Zona de la página a la que pertenece un bloque de texto.
enum PageZone: String {
    case header
    case body
    case footer
}

struct ClassifiedBlock {
    let block: OCRTextBlock
    let zone: PageZone
}

/// Clasifica los bloques de texto reconocidos en encabezado, cuerpo y pie.
///
/// La detección es **posicional**: un bloque cuyo centro vertical cae dentro de
/// la franja superior de la página se considera encabezado; si cae en la franja
/// inferior, pie. El grosor de cada franja lo controla el usuario en Ajustes.
/// Cuando la opción "omitir encabezados y pies" está activa, esos bloques no se
/// añaden a la capa de texto buscable (las búsquedas no encontrarán números de
/// página ni títulos de cabecera repetidos).
struct HeaderFooterDetector {

    func classify(
        _ blocks: [OCRTextBlock],
        headerThreshold: Double,
        footerThreshold: Double
    ) -> [ClassifiedBlock] {
        blocks.map { block in
            // boundingBox usa origen abajo-izquierda: midY alto = parte superior.
            let midY = block.boundingBox.midY
            let zone: PageZone
            if headerThreshold > 0, midY >= 1.0 - headerThreshold {
                zone = .header
            } else if footerThreshold > 0, midY <= footerThreshold {
                zone = .footer
            } else {
                zone = .body
            }
            return ClassifiedBlock(block: block, zone: zone)
        }
    }

    /// Devuelve los bloques que deben escribirse en la capa de texto buscable,
    /// excluyendo encabezados y pies si así lo pide la configuración.
    func searchableBlocks(
        from blocks: [OCRTextBlock],
        excludeHeadersFooters: Bool,
        headerThreshold: Double,
        footerThreshold: Double
    ) -> [OCRTextBlock] {
        guard excludeHeadersFooters else { return blocks }
        return classify(
            blocks,
            headerThreshold: headerThreshold,
            footerThreshold: footerThreshold
        )
        .filter { $0.zone == .body }
        .map { $0.block }
    }
}
