import SwiftUI

/// Punto de entrada de la aplicación.
@main
struct LucentPDFApp: App {

    @StateObject private var settings: AppSettings
    @StateObject private var viewModel: MainViewModel
    @StateObject private var updater: UpdateService

    init() {
        let appSettings = AppSettings()
        _settings = StateObject(wrappedValue: appSettings)
        _viewModel = StateObject(wrappedValue: MainViewModel(settings: appSettings))
        _updater = StateObject(wrappedValue: UpdateService())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(viewModel)
                .environmentObject(settings)
                .environmentObject(updater)
                .frame(minWidth: 820, minHeight: 600)
        }
        .defaultSize(width: 960, height: 680)
        .windowResizability(.contentMinSize)
        .commands {
            // "Buscar actualizaciones" en el menú de la aplicación.
            CommandGroup(after: .appInfo) {
                Button("Buscar actualizaciones…") {
                    updater.checkForUpdates()
                }
            }
            // La app no crea documentos: se retira la opción "Nuevo".
            CommandGroup(replacing: .newItem) {}
        }

        // Ventana de Ajustes (Preferencias, ⌘,).
        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(updater)
        }
    }
}
