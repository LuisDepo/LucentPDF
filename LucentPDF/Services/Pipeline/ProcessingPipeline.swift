import CoreGraphics
import Foundation
import PDFKit

/// Orquesta el procesamiento por lotes de extremo a extremo.
///
/// Estrategia para lotes grandes:
/// - Se procesa **un archivo y una página a la vez**; la página se escribe de
///   inmediato en el PDF de salida y su imagen se libera. El consumo de memoria
///   no crece con el tamaño del lote.
/// - El trabajo se ejecuta en una tarea en segundo plano; la interfaz nunca se
///   bloquea y el progreso se publica al hilo principal.
/// - Es cancelable en los límites de página.
/// - Si un archivo falla, se registra el error y se continúa con el resto; el
///   PDF final se genera igualmente con los archivos correctos.
struct ProcessingPipeline {

    private let log = AppLog.shared

    func process(
        files: [PDFFileItem],
        options: ProcessingOptions,
        outputURL: URL,
        progress: @escaping @MainActor (ProcessingProgress) -> Void
    ) async throws -> ProcessingReport {

        let detector = PDFTextDetector()
        let rasterizer = PDFRasterizer()
        let orientation = OrientationNormalizer()
        let headerFooter = HeaderFooterDetector()
        let coordinator = OCRCoordinator(options: options)

        let startedAt = Date()
        let title = outputURL.deletingPathExtension().lastPathComponent
        let assembler = try PDFAssembler(outputURL: outputURL, title: title)

        let totalPages = max(1, files.reduce(0) { $0 + $1.pageCount })
        var processedPages = 0
        var outcomes: [FileOutcome] = []
        var wasCancelled = false

        log.reset()
        log.info("Procesamiento iniciado: \(files.count) archivos, ~\(totalPages) páginas.")
        log.info("Motor primario: Apple Vision. Respaldo Tesseract: "
            + (coordinator.fallbackAvailable ? "disponible." : "no disponible (solo Vision)."))
        log.info("Resolución OCR: \(options.rasterDPI) ppp. Orden de combinación: "
            + options.sortStrategy.displayName + ".")

        await progress(ProcessingProgress(
            phase: "Preparando…", currentFileIndex: 0, totalFiles: files.count,
            currentFileName: "", processedPages: 0, totalPages: totalPages))

        fileLoop: for (index, file) in files.enumerated() {
            if Task.isCancelled { wasCancelled = true; break fileLoop }

            let fileStart = Date()
            await progress(ProcessingProgress(
                phase: "Procesando documento", currentFileIndex: index + 1,
                totalFiles: files.count, currentFileName: file.fileName,
                processedPages: processedPages, totalPages: totalPages))

            guard let cgDocument = CGPDFDocument(file.url as CFURL) else {
                log.error("No se pudo abrir el documento: \(file.relativePath)")
                outcomes.append(FileOutcome(
                    id: UUID(), relativePath: file.relativePath, fileName: file.fileName,
                    status: .failed, totalPages: file.pageCount, ocrPages: 0,
                    enginesUsed: [], detail: "El archivo no se pudo abrir o está dañado.",
                    duration: Date().timeIntervalSince(fileStart)))
                continue
            }

            let pdfKitDocument = PDFDocument(url: file.url)
            let pageCount = cgDocument.numberOfPages
            var ocrPages = 0
            var degradedPages = 0
            var enginesUsed = Set<OCREngineKind>()

            if pageCount > 0 {
                for pageIndex in 1...pageCount {
                    if Task.isCancelled { wasCancelled = true; break fileLoop }
                    guard let cgPage = cgDocument.page(at: pageIndex) else {
                        degradedPages += 1
                        continue
                    }

                    var handledAsDigital = false
                    if options.skipDigitalText,
                       let pdfKitDocument,
                       pageIndex - 1 < pdfKitDocument.pageCount,
                       let pdfPage = pdfKitDocument.page(at: pageIndex - 1),
                       detector.hasDigitalText(pdfPage) {
                        assembler.appendOriginalPage(cgPage)
                        handledAsDigital = true
                    }

                    if !handledAsDigital {
                        if let raster = rasterizer.rasterize(cgPage, dpi: options.rasterDPI) {
                            var image = raster
                            if options.correctOrientation {
                                image = orientation.normalize(
                                    image, languages: options.visionLanguages).image
                            }
                            let recognition = coordinator.recognize(image: image)
                            recognition.enginesAttempted.forEach { enginesUsed.insert($0) }

                            let searchable = headerFooter.searchableBlocks(
                                from: recognition.page.blocks,
                                excludeHeadersFooters: options.excludeHeadersFooters,
                                headerThreshold: options.headerThreshold,
                                footerThreshold: options.footerThreshold)

                            let scale = CGFloat(options.rasterDPI) / 72.0
                            let pageSize = CGSize(
                                width: CGFloat(image.width) / scale,
                                height: CGFloat(image.height) / scale)
                            assembler.appendImagePage(
                                image: image, size: pageSize, textBlocks: searchable)
                            ocrPages += 1
                        } else {
                            // No se pudo rasterizar: se copia la página original
                            // para no perder contenido, pero sin capa OCR nueva.
                            log.warning("Página \(pageIndex) de \(file.relativePath) "
                                + "no rasterizable; copiada sin OCR.")
                            assembler.appendOriginalPage(cgPage)
                            degradedPages += 1
                        }
                    }

                    processedPages += 1
                    await progress(ProcessingProgress(
                        phase: "Aplicando OCR", currentFileIndex: index + 1,
                        totalFiles: files.count, currentFileName: file.fileName,
                        processedPages: processedPages, totalPages: totalPages))
                }
            }

            let status: FileOutcomeStatus
            let detail: String?
            if pageCount == 0 {
                status = .failed
                detail = "El documento no contiene páginas."
            } else if degradedPages > 0 {
                status = .partial
                detail = "\(degradedPages) de \(pageCount) páginas se incluyeron sin OCR "
                    + "(no se pudieron rasterizar)."
            } else if ocrPages == 0 {
                status = .skippedText
                detail = "Todas las páginas ya tenían texto digital; se conservaron."
            } else {
                status = .success
                detail = nil
            }

            outcomes.append(FileOutcome(
                id: UUID(), relativePath: file.relativePath, fileName: file.fileName,
                status: status, totalPages: pageCount, ocrPages: ocrPages,
                enginesUsed: Array(enginesUsed).sorted { $0.rawValue < $1.rawValue },
                detail: detail, duration: Date().timeIntervalSince(fileStart)))
            log.info("\(file.relativePath): \(status.displayName) "
                + "— \(ocrPages)/\(pageCount) páginas con OCR.")
        }

        assembler.finish()
        let finishedAt = Date()

        if wasCancelled {
            log.warning("Procesamiento cancelado por el usuario.")
            try? FileManager.default.removeItem(at: outputURL)
            return ProcessingReport(
                startedAt: startedAt, finishedAt: finishedAt, outcomes: outcomes,
                outputURL: nil, outputByteSize: 0, wasCancelled: true)
        }

        let attributes = try? FileManager.default.attributesOfItem(atPath: outputURL.path)
        let outputSize = (attributes?[.size] as? NSNumber)?.int64Value ?? 0

        log.info("Procesamiento finalizado en \(String(format: "%.1f", finishedAt.timeIntervalSince(startedAt))) s. "
            + "PDF generado con \(assembler.pageCount) páginas.")

        return ProcessingReport(
            startedAt: startedAt, finishedAt: finishedAt, outcomes: outcomes,
            outputURL: outputURL, outputByteSize: outputSize, wasCancelled: false)
    }
}
