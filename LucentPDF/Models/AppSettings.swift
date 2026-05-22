import Combine
import Foundation

/// Instantánea inmutable y `Sendable` de los ajustes, segura para cruzar a las
/// tareas en segundo plano del pipeline de procesamiento.
struct ProcessingOptions: Sendable {
    var sortStrategy: SortStrategy
    var skipDigitalText: Bool
    var excludeHeadersFooters: Bool
    /// Fracción de la página (0...1) considerada encabezado (medida desde arriba).
    var headerThreshold: Double
    /// Fracción de la página (0...1) considerada pie (medida desde abajo).
    var footerThreshold: Double
    var correctOrientation: Bool
    var enableTesseractFallback: Bool
    /// Idiomas para Apple Vision (códigos BCP-47, p. ej. "es-ES").
    var visionLanguages: [String]
    /// Idiomas para Tesseract (códigos ISO 639-2, p. ej. "spa").
    var tesseractLanguages: [String]
    /// Resolución de rasterización para OCR, en puntos por pulgada.
    var rasterDPI: Int
}

/// Ajustes del usuario, persistidos en `UserDefaults`.
@MainActor
final class AppSettings: ObservableObject {

    @Published var sortStrategy: SortStrategy { didSet { save() } }
    @Published var skipDigitalText: Bool { didSet { save() } }
    @Published var excludeHeadersFooters: Bool { didSet { save() } }
    @Published var headerThresholdPercent: Double { didSet { save() } }
    @Published var footerThresholdPercent: Double { didSet { save() } }
    @Published var correctOrientation: Bool { didSet { save() } }
    @Published var enableTesseractFallback: Bool { didSet { save() } }
    @Published var recognizeSpanish: Bool { didSet { save() } }
    @Published var recognizeEnglish: Bool { didSet { save() } }
    @Published var rasterDPI: Int { didSet { save() } }

    private let defaults: UserDefaults
    private var isLoading = true

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        sortStrategy = SortStrategy(rawValue: defaults.string(forKey: Keys.sort) ?? "")
            ?? .pathThenName
        skipDigitalText = defaults.object(forKey: Keys.skipDigital) as? Bool ?? true
        excludeHeadersFooters = defaults.object(forKey: Keys.excludeHF) as? Bool ?? false
        headerThresholdPercent = defaults.object(forKey: Keys.headerPct) as? Double ?? 8
        footerThresholdPercent = defaults.object(forKey: Keys.footerPct) as? Double ?? 8
        correctOrientation = defaults.object(forKey: Keys.orientation) as? Bool ?? true
        enableTesseractFallback = defaults.object(forKey: Keys.tesseract) as? Bool ?? true
        recognizeSpanish = defaults.object(forKey: Keys.spanish) as? Bool ?? true
        recognizeEnglish = defaults.object(forKey: Keys.english) as? Bool ?? true
        rasterDPI = defaults.object(forKey: Keys.dpi) as? Int ?? 300

        isLoading = false
    }

    private func save() {
        guard !isLoading else { return }
        defaults.set(sortStrategy.rawValue, forKey: Keys.sort)
        defaults.set(skipDigitalText, forKey: Keys.skipDigital)
        defaults.set(excludeHeadersFooters, forKey: Keys.excludeHF)
        defaults.set(headerThresholdPercent, forKey: Keys.headerPct)
        defaults.set(footerThresholdPercent, forKey: Keys.footerPct)
        defaults.set(correctOrientation, forKey: Keys.orientation)
        defaults.set(enableTesseractFallback, forKey: Keys.tesseract)
        defaults.set(recognizeSpanish, forKey: Keys.spanish)
        defaults.set(recognizeEnglish, forKey: Keys.english)
        defaults.set(rasterDPI, forKey: Keys.dpi)
    }

    /// Construye la instantánea `Sendable` para el pipeline.
    func makeOptions() -> ProcessingOptions {
        var vision: [String] = []
        var tess: [String] = []
        if recognizeSpanish { vision.append("es-ES"); tess.append("spa") }
        if recognizeEnglish { vision.append("en-US"); tess.append("eng") }
        // Garantía: si el usuario desactiva ambos, se reconocen los dos.
        if vision.isEmpty { vision = ["es-ES", "en-US"]; tess = ["spa", "eng"] }

        return ProcessingOptions(
            sortStrategy: sortStrategy,
            skipDigitalText: skipDigitalText,
            excludeHeadersFooters: excludeHeadersFooters,
            headerThreshold: max(0, min(0.25, headerThresholdPercent / 100)),
            footerThreshold: max(0, min(0.25, footerThresholdPercent / 100)),
            correctOrientation: correctOrientation,
            enableTesseractFallback: enableTesseractFallback,
            visionLanguages: vision,
            tesseractLanguages: tess,
            rasterDPI: max(150, min(450, rasterDPI))
        )
    }

    private enum Keys {
        static let sort = "settings.sortStrategy"
        static let skipDigital = "settings.skipDigitalText"
        static let excludeHF = "settings.excludeHeadersFooters"
        static let headerPct = "settings.headerThresholdPercent"
        static let footerPct = "settings.footerThresholdPercent"
        static let orientation = "settings.correctOrientation"
        static let tesseract = "settings.enableTesseractFallback"
        static let spanish = "settings.recognizeSpanish"
        static let english = "settings.recognizeEnglish"
        static let dpi = "settings.rasterDPI"
    }
}
