import Combine
import Foundation
import Sparkle

/// Servicio de auto-actualización basado en **Sparkle 2**, el estándar para
/// apps de macOS distribuidas fuera de la App Store.
///
/// El flujo es real (no simulado): Sparkle descarga el *appcast* indicado en
/// `SUFeedURL` (Info.plist), compara versiones, descarga el DMG y aplica la
/// actualización. Para que la instalación funcione en producción hay que:
///  1. Generar las claves EdDSA y poner la pública en `SUPublicEDKey`.
///  2. Publicar el `appcast.xml` en la URL de `SUFeedURL`.
/// Ambos pasos están documentados en `docs/DISTRIBUCION.md`. Mientras los
/// valores sean placeholders, la comprobación se ejecuta pero no se instalará
/// ninguna actualización.
@MainActor
final class UpdateService: ObservableObject {

    private let updaterController: SPUStandardUpdaterController

    /// Si la app debe comprobar actualizaciones automáticamente en segundo plano.
    @Published var automaticallyChecks: Bool {
        didSet {
            updaterController.updater.automaticallyChecksForUpdates = automaticallyChecks
        }
    }

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        automaticallyChecks = updaterController.updater.automaticallyChecksForUpdates
    }

    /// Lanza el flujo de comprobación de actualizaciones con la interfaz de Sparkle.
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    /// Versión visible (CFBundleShortVersionString).
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// Número de build (CFBundleVersion).
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    /// URL del feed configurada (para mostrarla en Ajustes).
    var feedURLString: String {
        Bundle.main.infoDictionary?["SUFeedURL"] as? String ?? "—"
    }
}
