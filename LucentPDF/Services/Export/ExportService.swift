import Foundation

/// Gestiona la escritura de los resultados a las ubicaciones elegidas por el
/// usuario: el PDF final, el reporte de incidencias y el log técnico.
struct ExportService {

    enum ExportError: LocalizedError {
        case temporaryFileMissing
        var errorDescription: String? {
            "El PDF generado no se encontró. Vuelve a procesar la carpeta."
        }
    }

    /// Copia el PDF temporal a la ubicación final elegida en el diálogo
    /// "Guardar como…". Funciona aunque origen y destino estén en volúmenes
    /// distintos.
    func finalizeOutput(temporaryURL: URL, destination: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: temporaryURL.path) else {
            throw ExportError.temporaryFileMissing
        }
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.copyItem(at: temporaryURL, to: destination)
        try? fm.removeItem(at: temporaryURL)
    }

    /// Escribe el log técnico exportable.
    func writeTechnicalLog(to url: URL) throws {
        try AppLog.shared.exportText().write(to: url, atomically: true, encoding: .utf8)
    }

    /// Escribe el reporte de incidencias junto al PDF (solo si hubo errores).
    /// Devuelve la URL del reporte, o `nil` si no había incidencias.
    @discardableResult
    func writeIncidentReportIfNeeded(for report: ProcessingReport, nextTo pdfURL: URL) -> URL? {
        guard !report.errors.isEmpty else { return nil }
        let reportURL = pdfURL
            .deletingPathExtension()
            .appendingPathExtension("incidencias.txt")
        let text = Self.incidentReportText(for: report)
        try? text.write(to: reportURL, atomically: true, encoding: .utf8)
        return reportURL
    }

    /// Texto legible del reporte de incidencias / resumen de la ejecución.
    static func incidentReportText(for report: ProcessingReport) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium

        var lines: [String] = []
        lines.append("LucentPDF — Reporte de procesamiento")
        lines.append(String(repeating: "=", count: 52))
        lines.append("Inicio:    \(dateFormatter.string(from: report.startedAt))")
        lines.append("Fin:       \(dateFormatter.string(from: report.finishedAt))")
        lines.append("Duración:  \(Formatters.duration(report.duration))")
        lines.append("")
        lines.append("Archivos correctos: \(report.successCount)")
        lines.append("Archivos parciales: \(report.partialCount)")
        lines.append("Archivos fallidos:  \(report.failedCount)")
        lines.append("Páginas con OCR:    \(report.totalOCRPages)")
        if let outputURL = report.outputURL {
            lines.append("PDF final:          \(outputURL.path)")
            lines.append("Tamaño final:       \(Formatters.fileSize(report.outputByteSize))")
        }
        lines.append("")

        if report.errors.isEmpty {
            lines.append("No se registraron incidencias.")
        } else {
            lines.append("INCIDENCIAS POR ARCHIVO")
            lines.append(String(repeating: "-", count: 52))
            for outcome in report.errors {
                lines.append("• \(outcome.relativePath)")
                lines.append("  Estado: \(outcome.status.displayName)")
                if let detail = outcome.detail {
                    lines.append("  Detalle: \(detail)")
                }
            }
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }
}
