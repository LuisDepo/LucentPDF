import Foundation
import os

enum LogLevel: String, Sendable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}

struct LogEntry: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let level: LogLevel
    let message: String
}

/// Registro técnico de la aplicación, seguro entre hilos.
///
/// Acumula entradas en memoria (para exportarlas si hay soporte) y las refleja
/// en el log unificado del sistema (`os.Logger`). Es `@unchecked Sendable`: la
/// mutación del array está protegida por un `NSLock`.
final class AppLog: @unchecked Sendable {

    static let shared = AppLog()

    private let lock = NSLock()
    private var entries: [LogEntry] = []
    private let osLog = Logger(subsystem: "com.lucentpdf.app", category: "pipeline")
    private let maxEntries = 20_000

    private init() {}

    func log(_ level: LogLevel, _ message: String) {
        let entry = LogEntry(date: Date(), level: level, message: message)
        lock.lock()
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        lock.unlock()

        switch level {
        case .debug: osLog.debug("\(message, privacy: .public)")
        case .info: osLog.info("\(message, privacy: .public)")
        case .warning: osLog.warning("\(message, privacy: .public)")
        case .error: osLog.error("\(message, privacy: .public)")
        }
    }

    func debug(_ m: String) { log(.debug, m) }
    func info(_ m: String) { log(.info, m) }
    func warning(_ m: String) { log(.warning, m) }
    func error(_ m: String) { log(.error, m) }

    /// Vacía el registro (al iniciar una ejecución nueva).
    func reset() {
        lock.lock()
        entries.removeAll()
        lock.unlock()
    }

    func snapshot() -> [LogEntry] {
        lock.lock(); defer { lock.unlock() }
        return entries
    }

    /// Genera el contenido de texto del log técnico para exportar.
    func exportText() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let header = """
        LucentPDF — Registro técnico
        Generado: \(formatter.string(from: Date()))
        ============================================================

        """
        let body = snapshot()
            .map { "\(formatter.string(from: $0.date)) [\($0.level.rawValue)] \($0.message)" }
            .joined(separator: "\n")
        return header + body + "\n"
    }
}
