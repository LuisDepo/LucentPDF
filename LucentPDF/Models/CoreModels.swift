import Foundation

/// Estrategia de ordenación con la que se combinan los PDF en el documento final.
///
/// Regla por defecto (`pathThenName`): los archivos se ordenan por su ruta
/// relativa completa respecto a la carpeta raíz y, dentro de cada carpeta, por
/// nombre de archivo. La comparación es "localizada y естественная" (number-aware),
/// de modo que `cap2` va antes que `cap10`. El orden es **estable y reproducible**
/// entre ejecuciones porque la ruta relativa es única para cada archivo.
enum SortStrategy: String, CaseIterable, Identifiable, Codable {
    case pathThenName
    case nameOnly
    case dateModified

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pathThenName: return "Ruta de carpeta y nombre"
        case .nameOnly: return "Nombre de archivo"
        case .dateModified: return "Fecha de modificación"
        }
    }

    var explanation: String {
        switch self {
        case .pathThenName:
            return "Ordena por la ruta de la subcarpeta y, dentro de cada una, por nombre. Predecible y estable."
        case .nameOnly:
            return "Ordena solo por nombre de archivo, ignorando la carpeta donde está."
        case .dateModified:
            return "Ordena por fecha de modificación, del más antiguo al más reciente."
        }
    }
}

/// Un archivo PDF descubierto dentro de la carpeta raíz.
struct PDFFileItem: Identifiable, Hashable, Sendable {
    let id: UUID
    /// Ubicación absoluta en disco.
    let url: URL
    /// Ruta relativa a la carpeta raíz seleccionada (incluye subcarpetas).
    let relativePath: String
    /// Nombre del archivo con extensión.
    let fileName: String
    /// Tamaño en bytes.
    let byteSize: Int64
    /// Número de páginas (0 si el PDF no se pudo abrir durante el escaneo).
    let pageCount: Int
    /// Fecha de última modificación.
    let modifiedDate: Date

    init(
        id: UUID = UUID(),
        url: URL,
        relativePath: String,
        fileName: String,
        byteSize: Int64,
        pageCount: Int,
        modifiedDate: Date
    ) {
        self.id = id
        self.url = url
        self.relativePath = relativePath
        self.fileName = fileName
        self.byteSize = byteSize
        self.pageCount = pageCount
        self.modifiedDate = modifiedDate
    }

    /// Carpeta relativa que contiene el archivo (cadena vacía si está en la raíz).
    var relativeDirectory: String {
        let dir = (relativePath as NSString).deletingLastPathComponent
        return dir
    }
}

/// Resultado del escaneo de una carpeta raíz.
struct ScanSummary: Sendable {
    let rootURL: URL
    let files: [PDFFileItem]
    let scanDate: Date

    var fileCount: Int { files.count }
    var totalBytes: Int64 { files.reduce(0) { $0 + $1.byteSize } }
    var totalPages: Int { files.reduce(0) { $0 + $1.pageCount } }

    /// Lista de subcarpetas distintas que contienen PDF, ordenadas.
    var directories: [String] {
        let dirs = Set(files.map { $0.relativeDirectory })
        return dirs.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}
