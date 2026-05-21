import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Mensaje de alerta presentado al usuario.
struct AlertMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

/// ViewModel central de la app. Coordina el flujo completo (escaneo →
/// revisión → procesamiento → resultados) y mantiene el estado de la interfaz.
/// Aislado al hilo principal; el trabajo pesado se delega a tareas
/// `Task.detached`.
@MainActor
final class MainViewModel: ObservableObject {

    @Published private(set) var stage: AppStage = .welcome
    @Published private(set) var scanSummary: ScanSummary?
    @Published private(set) var displayedFiles: [PDFFileItem] = []
    @Published private(set) var scanError: String?
    @Published private(set) var progress: ProcessingProgress = .initial
    @Published private(set) var report: ProcessingReport?
    @Published var alertMessage: AlertMessage?

    let settings: AppSettings

    private let discovery = FileDiscoveryService()
    private let pipeline = ProcessingPipeline()
    private let exporter = ExportService()

    private var scanTask: Task<Void, Never>?
    private var processingTask: Task<Void, Never>?
    /// PDF temporal generado pero aún no guardado por el usuario.
    private var pendingOutputURL: URL?

    init(settings: AppSettings) {
        self.settings = settings
    }

    var isProcessing: Bool { stage == .processing }

    /// `true` si hay un PDF generado pendiente de guardar (el usuario canceló
    /// el diálogo "Guardar como…").
    var hasUnsavedResult: Bool { pendingOutputURL != nil }

    // MARK: - Selección y escaneo de carpeta

    /// Abre el diálogo nativo de selección de carpeta.
    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Seleccionar"
        panel.message = "Elige la carpeta raíz que contiene los PDF"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        scanFolder(at: url)
    }

    /// Escanea de forma recursiva la carpeta indicada.
    func scanFolder(at url: URL) {
        scanTask?.cancel()
        stage = .scanning
        scanError = nil
        scanSummary = nil
        displayedFiles = []

        let strategy = settings.sortStrategy
        let discovery = self.discovery

        scanTask = Task { [weak self] in
            do {
                let summary = try await Task.detached(priority: .userInitiated) {
                    try await discovery.discoverPDFs(in: url, sort: strategy)
                }.value
                guard let self else { return }
                if summary.files.isEmpty {
                    self.scanError = "No se encontraron archivos PDF en «\(url.lastPathComponent)» ni en sus subcarpetas."
                    self.stage = .welcome
                } else {
                    self.scanSummary = summary
                    self.displayedFiles = summary.files
                    self.stage = .review
                }
            } catch is CancellationError {
                // Escaneo reemplazado por otro: se ignora.
            } catch {
                guard let self else { return }
                self.scanError = error.localizedDescription
                self.stage = .welcome
            }
        }
    }

    /// Maneja una carpeta soltada sobre la ventana (drag & drop).
    func handleDroppedFolder(_ url: URL) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            scanError = "Suelta una carpeta, no un archivo."
            return
        }
        scanFolder(at: url)
    }

    // MARK: - Orden de combinación

    /// Cambia la estrategia de orden y reordena la lista mostrada.
    func applySortStrategy(_ strategy: SortStrategy) {
        settings.sortStrategy = strategy
        displayedFiles = FileDiscoveryService.sort(displayedFiles, by: strategy)
    }

    // MARK: - Procesamiento

    func startProcessing() {
        guard let summary = scanSummary, !displayedFiles.isEmpty else { return }

        let options = settings.makeOptions()
        let orderedFiles = FileDiscoveryService.sort(displayedFiles, by: options.sortStrategy)
        let rootName = summary.rootURL.lastPathComponent
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LucentPDF-\(UUID().uuidString).pdf")

        stage = .processing
        progress = .initial
        report = nil
        pendingOutputURL = nil

        let pipeline = self.pipeline

        processingTask = Task { [weak self] in
            let progressHandler: @MainActor (ProcessingProgress) -> Void = { update in
                self?.progress = update
            }
            do {
                let producedReport = try await Task.detached(priority: .userInitiated) {
                    try await pipeline.process(
                        files: orderedFiles,
                        options: options,
                        outputURL: tempURL,
                        progress: progressHandler)
                }.value
                guard let self else { return }
                if producedReport.wasCancelled {
                    self.stage = .review
                } else {
                    self.completeProcessing(producedReport, temporaryURL: tempURL, rootName: rootName)
                }
            } catch {
                guard let self else { return }
                try? FileManager.default.removeItem(at: tempURL)
                self.stage = .review
                self.alertMessage = AlertMessage(
                    title: "No se pudo generar el PDF",
                    message: error.localizedDescription)
            }
        }
    }

    /// Cancela el procesamiento en curso.
    func cancelProcessing() {
        processingTask?.cancel()
    }

    /// Tras generar el PDF temporal, pide al usuario dónde guardarlo.
    private func completeProcessing(
        _ report: ProcessingReport, temporaryURL: URL, rootName: String
    ) {
        pendingOutputURL = temporaryURL
        self.report = report
        stage = .results
        // Diálogo "Guardar como…" inmediatamente después de procesar.
        saveProcessedPDF(defaultName: "\(rootName) — combinado.pdf")
    }

    /// Presenta el diálogo "Guardar como…" y finaliza la exportación.
    func saveProcessedPDF(defaultName: String = "LucentPDF — combinado.pdf") {
        guard let temporaryURL = pendingOutputURL, var report else { return }

        let panel = NSSavePanel()
        panel.title = "Guardar PDF combinado"
        panel.nameFieldStringValue = defaultName
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let destination = panel.url else { return }

        do {
            try exporter.finalizeOutput(temporaryURL: temporaryURL, destination: destination)
            let attributes = try? FileManager.default.attributesOfItem(atPath: destination.path)
            report.outputURL = destination
            report.outputByteSize = (attributes?[.size] as? NSNumber)?.int64Value
                ?? report.outputByteSize
            exporter.writeIncidentReportIfNeeded(for: report, nextTo: destination)
            self.report = report
            self.pendingOutputURL = nil
        } catch {
            alertMessage = AlertMessage(
                title: "No se pudo guardar el PDF",
                message: error.localizedDescription)
        }
    }

    // MARK: - Acciones de resultados

    func openOutputPDF() {
        guard let url = report?.outputURL else { return }
        NSWorkspace.shared.open(url)
    }

    func revealOutputInFinder() {
        guard let url = report?.outputURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Exporta el log técnico para soporte.
    func exportTechnicalLog() {
        let panel = NSSavePanel()
        panel.title = "Exportar log técnico"
        panel.nameFieldStringValue = "LucentPDF-log.txt"
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try exporter.writeTechnicalLog(to: url)
        } catch {
            alertMessage = AlertMessage(
                title: "No se pudo exportar el log",
                message: error.localizedDescription)
        }
    }

    /// Vuelve a la pantalla inicial para procesar otra carpeta.
    func reset() {
        processingTask?.cancel()
        scanTask?.cancel()
        if let pendingOutputURL {
            try? FileManager.default.removeItem(at: pendingOutputURL)
        }
        scanSummary = nil
        displayedFiles = []
        scanError = nil
        report = nil
        progress = .initial
        pendingOutputURL = nil
        stage = .welcome
    }

    /// Vuelve de la revisión a la pantalla inicial.
    func backToWelcome() {
        scanTask?.cancel()
        scanSummary = nil
        displayedFiles = []
        stage = .welcome
    }
}
