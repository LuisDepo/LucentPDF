import Foundation

/// Formateadores de texto compartidos por la interfaz y los reportes.
enum Formatters {

    /// Tamaño de archivo legible (KB, MB, GB).
    static func fileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: max(0, bytes))
    }

    /// Duración legible en español.
    static func duration(_ seconds: TimeInterval) -> String {
        guard seconds >= 1 else { return "menos de 1 s" }
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 { return "\(hours) h \(minutes) min" }
        if minutes > 0 { return "\(minutes) min \(secs) s" }
        return "\(secs) s"
    }

    /// "1 página" / "N páginas".
    static func pageCount(_ count: Int) -> String {
        count == 1 ? "1 página" : "\(count) páginas"
    }

    /// "1 archivo" / "N archivos".
    static func fileCount(_ count: Int) -> String {
        count == 1 ? "1 archivo" : "\(count) archivos"
    }
}
