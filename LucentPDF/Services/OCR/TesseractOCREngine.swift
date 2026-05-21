import CoreGraphics
import Foundation

/// Motor de OCR de respaldo, basado en Tesseract.
///
/// El binario de Tesseract y sus librerías se empaquetan **dentro del bundle**
/// de la app (`Contents/Resources/Tesseract/`) por el script de build
/// `scripts/bundle_tesseract.sh`. El usuario final nunca ve una terminal: la
/// app invoca el binario de forma silenciosa mediante `Process`.
///
/// Si el binario no está presente (p. ej. el empaquetado falló en CI),
/// `isAvailable` devuelve `false` y el `OCRCoordinator` usa solo Vision. La app
/// sigue funcionando: la degradación es elegante.
final class TesseractOCREngine: OCREngine {

    let kind: OCREngineKind = .tesseract

    private let log = AppLog.shared
    private let processTimeout: TimeInterval = 180

    private var bundleRoot: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("Tesseract", isDirectory: true)
    }

    private var binaryURL: URL? {
        guard let root = bundleRoot else { return nil }
        let url = root.appendingPathComponent("bin/tesseract")
        return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
    }

    private var tessdataURL: URL? {
        bundleRoot?.appendingPathComponent("tessdata", isDirectory: true)
    }

    var isAvailable: Bool { binaryURL != nil && tessdataURL != nil }

    func recognize(image: CGImage, languages: [String]) throws -> OCRPageResult {
        guard let binary = binaryURL, let tessdata = tessdataURL else {
            throw OCREngineError.engineUnavailable
        }

        let tmp = FileManager.default.temporaryDirectory
        let token = UUID().uuidString
        let pngURL = tmp.appendingPathComponent("lucent-ocr-\(token).png")
        let errURL = tmp.appendingPathComponent("lucent-ocr-\(token).err")
        defer {
            try? FileManager.default.removeItem(at: pngURL)
            try? FileManager.default.removeItem(at: errURL)
        }

        try ImageUtilities.writePNG(image, to: pngURL)

        let langArgument = languages.isEmpty ? "spa+eng" : languages.joined(separator: "+")

        FileManager.default.createFile(atPath: errURL.path, contents: nil)
        guard let errorHandle = try? FileHandle(forWritingTo: errURL) else {
            throw OCREngineError.recognitionFailed("No se pudo preparar la salida de error.")
        }

        let process = Process()
        process.executableURL = binary
        process.arguments = [pngURL.path, "stdout", "tsv", "-l", langArgument, "--psm", "3"]
        var environment = ProcessInfo.processInfo.environment
        environment["TESSDATA_PREFIX"] = tessdata.path
        process.environment = environment

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorHandle

        do {
            try process.run()
        } catch {
            errorHandle.closeFile()
            throw OCREngineError.recognitionFailed(
                "No se pudo ejecutar Tesseract: \(error.localizedDescription)")
        }

        // Watchdog: termina el proceso si se bloquea.
        let watchdog = DispatchWorkItem {
            if process.isRunning { process.terminate() }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + processTimeout, execute: watchdog)

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        watchdog.cancel()
        errorHandle.closeFile()

        guard process.terminationStatus == 0 else {
            let stderr = (try? String(contentsOf: errURL, encoding: .utf8)) ?? ""
            throw OCREngineError.recognitionFailed(
                "Tesseract terminó con código \(process.terminationStatus). \(stderr)")
        }

        let tsv = String(data: outputData, encoding: .utf8) ?? ""
        let blocks = Self.parseTSV(tsv, imageWidth: image.width, imageHeight: image.height)
        return OCRPageResult(blocks: blocks, engine: .tesseract)
    }

    /// Convierte la salida TSV de Tesseract en bloques con recuadro normalizado.
    ///
    /// Columnas TSV: level, page, block, par, line, word, left, top, width,
    /// height, conf, text. `level == 5` corresponde a una palabra. Las
    /// coordenadas de Tesseract son en píxeles con origen arriba-izquierda; se
    /// convierten al sistema normalizado con origen abajo-izquierda.
    static func parseTSV(_ tsv: String, imageWidth: Int, imageHeight: Int) -> [OCRTextBlock] {
        guard imageWidth > 0, imageHeight > 0 else { return [] }
        let width = Double(imageWidth)
        let height = Double(imageHeight)
        var blocks: [OCRTextBlock] = []

        for rawLine in tsv.split(whereSeparator: { $0.isNewline }) {
            let columns = rawLine
                .split(separator: "\t", omittingEmptySubsequences: false)
                .map(String.init)
            guard columns.count >= 12, columns[0] == "5" else { continue }
            guard
                let left = Double(columns[6]),
                let top = Double(columns[7]),
                let boxWidth = Double(columns[8]),
                let boxHeight = Double(columns[9]),
                let confidence = Double(columns[10])
            else { continue }

            let text = columns[11].trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty, confidence >= 0, boxWidth > 0, boxHeight > 0 else { continue }

            let rect = CGRect(
                x: left / width,
                y: 1.0 - (top + boxHeight) / height,
                width: boxWidth / width,
                height: boxHeight / height
            )
            blocks.append(OCRTextBlock(
                text: text,
                boundingBox: rect,
                confidence: confidence / 100.0
            ))
        }
        return blocks
    }
}
