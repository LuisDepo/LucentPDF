import CoreGraphics
import XCTest
@testable import LucentPDF

/// Pruebas de la lógica pura de LucentPDF (orden, parseo de OCR, formateo).
final class LucentPDFTests: XCTestCase {

    // MARK: - Orden de combinación

    private func item(_ relativePath: String, date: Date = Date()) -> PDFFileItem {
        PDFFileItem(
            url: URL(fileURLWithPath: "/tmp/\(relativePath)"),
            relativePath: relativePath,
            fileName: (relativePath as NSString).lastPathComponent,
            byteSize: 1_000,
            pageCount: 1,
            modifiedDate: date
        )
    }

    func testSortByPathThenNameIsNumberAware() {
        let input = [
            item("b/doc2.pdf"),
            item("a/doc10.pdf"),
            item("a/doc2.pdf"),
            item("a.pdf"),
        ]
        let sorted = FileDiscoveryService.sort(input, by: .pathThenName)
        XCTAssertEqual(
            sorted.map(\.relativePath),
            ["a.pdf", "a/doc2.pdf", "a/doc10.pdf", "b/doc2.pdf"])
    }

    func testSortIsStableAndDeterministic() {
        let input = [item("z/1.pdf"), item("a/1.pdf"), item("m/1.pdf")]
        let first = FileDiscoveryService.sort(input, by: .pathThenName)
        let second = FileDiscoveryService.sort(input.reversed(), by: .pathThenName)
        XCTAssertEqual(first.map(\.relativePath), second.map(\.relativePath))
    }

    func testSortByDateModified() {
        let old = Date(timeIntervalSince1970: 1_000)
        let recent = Date(timeIntervalSince1970: 9_000)
        let input = [item("b.pdf", date: recent), item("a.pdf", date: old)]
        let sorted = FileDiscoveryService.sort(input, by: .dateModified)
        XCTAssertEqual(sorted.map(\.relativePath), ["a.pdf", "b.pdf"])
    }

    // MARK: - Parseo de la salida TSV de Tesseract

    func testParseTSVProducesNormalizedBlocks() {
        let tsv = [
            "level\tpage\tblock\tpar\tline\tword\tleft\ttop\twidth\theight\tconf\ttext",
            "5\t1\t1\t1\t1\t1\t100\t200\t300\t60\t95.5\tHola",
            "5\t1\t1\t1\t1\t2\t450\t200\t250\t60\t88.0\tMundo",
            "4\t1\t1\t1\t1\t0\t0\t0\t0\t0\t-1\t",
        ].joined(separator: "\n")

        let blocks = TesseractOCREngine.parseTSV(tsv, imageWidth: 1_000, imageHeight: 1_000)

        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].text, "Hola")
        XCTAssertEqual(blocks[0].confidence, 0.955, accuracy: 0.001)
        XCTAssertEqual(blocks[0].boundingBox.minX, 0.1, accuracy: 0.001)
        // origen abajo-izquierda: y = 1 - (top + height) / alto
        XCTAssertEqual(blocks[0].boundingBox.minY, 0.74, accuracy: 0.001)
    }

    func testParseTSVRejectsMalformedInput() {
        XCTAssertTrue(TesseractOCREngine.parseTSV("", imageWidth: 1_000, imageHeight: 1_000).isEmpty)
        XCTAssertTrue(TesseractOCREngine.parseTSV("basura", imageWidth: 0, imageHeight: 0).isEmpty)
    }

    // MARK: - Detección de encabezados y pies

    func testHeaderFooterClassification() {
        let detector = HeaderFooterDetector()
        let header = OCRTextBlock(
            text: "Capítulo 1",
            boundingBox: CGRect(x: 0.1, y: 0.95, width: 0.3, height: 0.03),
            confidence: 0.9)
        let body = OCRTextBlock(
            text: "Contenido",
            boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.6, height: 0.03),
            confidence: 0.9)
        let footer = OCRTextBlock(
            text: "Página 1",
            boundingBox: CGRect(x: 0.1, y: 0.03, width: 0.2, height: 0.03),
            confidence: 0.9)

        let kept = detector.searchableBlocks(
            from: [header, body, footer],
            excludeHeadersFooters: true,
            headerThreshold: 0.08,
            footerThreshold: 0.08)

        XCTAssertEqual(kept.map(\.text), ["Contenido"])

        let all = detector.searchableBlocks(
            from: [header, body, footer],
            excludeHeadersFooters: false,
            headerThreshold: 0.08,
            footerThreshold: 0.08)
        XCTAssertEqual(all.count, 3)
    }

    // MARK: - Formateadores

    func testFormatters() {
        XCTAssertEqual(Formatters.pageCount(1), "1 página")
        XCTAssertEqual(Formatters.pageCount(5), "5 páginas")
        XCTAssertEqual(Formatters.fileCount(1), "1 archivo")
        XCTAssertEqual(Formatters.fileCount(3), "3 archivos")
        XCTAssertEqual(Formatters.duration(0.4), "menos de 1 s")
        XCTAssertEqual(Formatters.duration(65), "1 min 5 s")
        XCTAssertEqual(Formatters.duration(3_700), "1 h 1 min")
    }

    // MARK: - Calidad del resultado OCR

    func testOCRPageResultQualityScore() {
        let strong = OCRPageResult(
            blocks: [
                OCRTextBlock(text: "uno dos tres",
                             boundingBox: .zero, confidence: 0.95),
            ],
            engine: .vision)
        let weak = OCRPageResult(
            blocks: [
                OCRTextBlock(text: "uno", boundingBox: .zero, confidence: 0.3),
            ],
            engine: .tesseract)
        XCTAssertGreaterThan(strong.qualityScore, weak.qualityScore)
    }
}
