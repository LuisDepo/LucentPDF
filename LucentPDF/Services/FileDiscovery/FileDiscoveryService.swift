import Foundation
import PDFKit

enum DiscoveryError: LocalizedError {
    case notADirectory
    case unreadable(URL)

    var errorDescription: String? {
        switch self {
        case .notADirectory:
            return "El elemento seleccionado no es una carpeta."
        case .unreadable(let url):
            return "No se pudo leer la carpeta: \(url.path)"
        }
    }
}

/// Descubre de forma recursiva todos los PDF dentro de una carpeta raíz.
struct FileDiscoveryService {

    private let log = AppLog.shared

    /// Recorre `root` y todas sus subcarpetas buscando archivos `.pdf`.
    /// Es cancelable mediante la cancelación de la `Task` que lo invoca.
    func discoverPDFs(in root: URL, sort: SortStrategy) async throws -> ScanSummary {
        let fm = FileManager.default

        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue else {
            throw DiscoveryError.notADirectory
        }

        let keys: [URLResourceKey] = [
            .isRegularFileKey, .fileSizeKey, .contentModificationDateKey
        ]
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw DiscoveryError.unreadable(root)
        }

        let rootComponents = root.standardizedFileURL.pathComponents
        var items: [PDFFileItem] = []
        var scanned = 0

        for case let fileURL as URL in enumerator {
            scanned += 1
            if scanned % 50 == 0 { try Task.checkCancellation() }

            guard fileURL.pathExtension.lowercased() == "pdf" else { continue }

            let values = try? fileURL.resourceValues(forKeys: Set(keys))
            let byteSize = Int64(values?.fileSize ?? 0)
            let modified = values?.contentModificationDate ?? Date.distantPast

            let comps = fileURL.standardizedFileURL.pathComponents
            let relative = comps.dropFirst(rootComponents.count).joined(separator: "/")

            let pageCount = PDFDocument(url: fileURL)?.pageCount ?? 0
            if pageCount == 0 {
                log.warning("PDF ilegible o vacío durante el escaneo: \(relative)")
            }

            items.append(PDFFileItem(
                url: fileURL,
                relativePath: relative.isEmpty ? fileURL.lastPathComponent : relative,
                fileName: fileURL.lastPathComponent,
                byteSize: byteSize,
                pageCount: pageCount,
                modifiedDate: modified
            ))
        }

        let sorted = Self.sort(items, by: sort)
        log.info("Escaneo completado: \(sorted.count) PDF encontrados en \(root.lastPathComponent).")
        return ScanSummary(rootURL: root, files: sorted, scanDate: Date())
    }

    /// Ordena la lista de archivos de forma **determinista** según la estrategia.
    /// Cada comparación incluye un criterio de desempate por ruta relativa para
    /// que el orden sea idéntico entre ejecuciones.
    static func sort(_ items: [PDFFileItem], by strategy: SortStrategy) -> [PDFFileItem] {
        switch strategy {
        case .pathThenName:
            return items.sorted { a, b in
                let cmp = a.relativePath.localizedStandardCompare(b.relativePath)
                if cmp != .orderedSame { return cmp == .orderedAscending }
                return a.url.path < b.url.path
            }
        case .nameOnly:
            return items.sorted { a, b in
                let cmp = a.fileName.localizedStandardCompare(b.fileName)
                if cmp != .orderedSame { return cmp == .orderedAscending }
                return a.relativePath.localizedStandardCompare(b.relativePath) == .orderedAscending
            }
        case .dateModified:
            return items.sorted { a, b in
                if a.modifiedDate != b.modifiedDate { return a.modifiedDate < b.modifiedDate }
                return a.relativePath.localizedStandardCompare(b.relativePath) == .orderedAscending
            }
        }
    }
}
