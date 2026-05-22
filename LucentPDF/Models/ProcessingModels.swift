import Foundation

/// Motor de OCR utilizado para una página o archivo.
enum OCREngineKind: String, Sendable {
    case vision = "Apple Vision"
    case tesseract = "Tesseract"
    case none = "Sin OCR"
}

/// Etapa actual del flujo de la aplicación (controla qué pantalla se muestra).
enum AppStage: Equatable {
    case welcome
    case scanning
    case review
    case processing
    case results
}

/// Cómo terminó el procesamiento de un archivo concreto.
enum FileOutcomeStatus: String, Sendable {
    case success      // OCR aplicado correctamente
    case skippedText  // tenía texto digital; se conservó sin reprocesar
    case partial      // algunas páginas fallaron, otras se incluyeron
    case failed       // no se pudo incluir ninguna página

    var displayName: String {
        switch self {
        case .success: return "Correcto"
        case .skippedText: return "Texto ya digital"
        case .partial: return "Parcial"
        case .failed: return "Fallido"
        }
    }
}

/// Resultado del procesamiento de un archivo individual.
struct FileOutcome: Identifiable, Sendable {
    let id: UUID
    let relativePath: String
    let fileName: String
    let status: FileOutcomeStatus
    /// Páginas totales del archivo de origen.
    let totalPages: Int
    /// Páginas a las que se aplicó OCR (excluye páginas ya digitales).
    let ocrPages: Int
    /// Motores que intervinieron (Vision y/o Tesseract).
    let enginesUsed: [OCREngineKind]
    /// Mensaje de error o detalle, si lo hay.
    let detail: String?
    let duration: TimeInterval

    var isError: Bool { status == .failed || status == .partial }
}

/// Progreso en vivo del procesamiento, publicado hacia la interfaz.
struct ProcessingProgress: Sendable {
    var phase: String
    var currentFileIndex: Int
    var totalFiles: Int
    var currentFileName: String
    var processedPages: Int
    var totalPages: Int

    /// Fracción global completada (0...1) ponderada por páginas.
    var fraction: Double {
        guard totalPages > 0 else { return 0 }
        return min(1, Double(processedPages) / Double(totalPages))
    }

    static let initial = ProcessingProgress(
        phase: "Preparando…",
        currentFileIndex: 0,
        totalFiles: 0,
        currentFileName: "",
        processedPages: 0,
        totalPages: 0
    )
}

/// Informe completo de una ejecución de procesamiento.
struct ProcessingReport: Sendable {
    let startedAt: Date
    let finishedAt: Date
    let outcomes: [FileOutcome]
    /// PDF final generado.
    var outputURL: URL?
    var outputByteSize: Int64
    /// `true` si el proceso se canceló a mitad.
    let wasCancelled: Bool

    var duration: TimeInterval { finishedAt.timeIntervalSince(startedAt) }

    var successCount: Int {
        outcomes.filter { $0.status == .success || $0.status == .skippedText }.count
    }
    var partialCount: Int { outcomes.filter { $0.status == .partial }.count }
    var failedCount: Int { outcomes.filter { $0.status == .failed }.count }

    var includedFileCount: Int {
        outcomes.filter { $0.status != .failed }.count
    }
    var totalOCRPages: Int { outcomes.reduce(0) { $0 + $1.ocrPages } }
    var errors: [FileOutcome] { outcomes.filter { $0.isError } }

    /// `true` si se generó un PDF aunque algunos archivos fallaran.
    var producedOutput: Bool { outputURL != nil }
}
