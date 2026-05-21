import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Vista raíz: barra superior fija y conmutación de pantallas según la etapa.
struct RootView: View {
    @EnvironmentObject private var viewModel: MainViewModel

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert(
            viewModel.alertMessage?.title ?? "",
            isPresented: Binding(
                get: { viewModel.alertMessage != nil },
                set: { presented in
                    if !presented { viewModel.alertMessage = nil }
                }
            ),
            presenting: viewModel.alertMessage
        ) { _ in
            Button("Aceptar", role: .cancel) {}
        } message: { message in
            Text(message.message)
        }
        .onDrop(of: [.fileURL], isTargeted: nil, perform: handleDrop)
    }

    private var topBar: some View {
        HStack {
            WordmarkView(symbolSize: 26, fontSize: 17)
            Spacer()
            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .medium))
            }
            .buttonStyle(.plain)
            .help("Ajustes")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.stage {
        case .welcome:
            WelcomeView()
        case .scanning:
            ScanningView()
        case .review:
            ReviewView()
        case .processing:
            ProcessingView()
        case .results:
            ResultsView()
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard viewModel.stage == .welcome, let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            Task { @MainActor in
                viewModel.handleDroppedFolder(url)
            }
        }
        return true
    }

    /// Abre la ventana de Ajustes (selector estándar en macOS 13+).
    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

/// Pantalla de espera durante el escaneo de la carpeta.
struct ScanningView: View {
    var body: some View {
        VStack(spacing: 18) {
            ProgressView()
                .controlSize(.large)
            Text("Buscando archivos PDF…")
                .font(.system(size: 15, weight: .medium))
            Text("Recorriendo todas las subcarpetas.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
