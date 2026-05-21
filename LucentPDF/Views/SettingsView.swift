import SwiftUI

/// Ventana de Ajustes (Preferencias).
struct SettingsView: View {
    var body: some View {
        TabView {
            ProcessingSettingsTab()
                .tabItem { Label("Procesamiento", systemImage: "slider.horizontal.3") }
            UpdatesSettingsTab()
                .tabItem { Label("Actualizaciones", systemImage: "arrow.triangle.2.circlepath") }
            AboutTab()
                .tabItem { Label("Acerca de", systemImage: "info.circle") }
        }
        .frame(width: 500)
    }
}

// MARK: - Procesamiento

private struct ProcessingSettingsTab: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Section("Idiomas de OCR") {
                Toggle("Español", isOn: $settings.recognizeSpanish)
                Toggle("Inglés", isOn: $settings.recognizeEnglish)
            }

            Section("Reconocimiento") {
                Picker("Resolución (calidad/velocidad)", selection: $settings.rasterDPI) {
                    Text("150 ppp · rápido").tag(150)
                    Text("200 ppp").tag(200)
                    Text("300 ppp · recomendado").tag(300)
                    Text("400 ppp · máxima calidad").tag(400)
                }
                Toggle("Corregir orientación de páginas giradas", isOn: $settings.correctOrientation)
                Toggle("Usar Tesseract como motor de respaldo", isOn: $settings.enableTesseractFallback)
                Toggle("Conservar páginas que ya tienen texto digital",
                       isOn: $settings.skipDigitalText)
            }

            Section("Encabezados y pies de página") {
                Toggle("Omitir encabezados y pies del texto buscable",
                       isOn: $settings.excludeHeadersFooters)
                Text("Cuando está activo, los números de página y títulos repetidos "
                    + "no se incluirán en las búsquedas del PDF final.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)

                if settings.excludeHeadersFooters {
                    VStack(alignment: .leading) {
                        Text("Franja de encabezado: \(Int(settings.headerThresholdPercent)) %")
                            .font(.system(size: 11))
                        Slider(value: $settings.headerThresholdPercent, in: 2...20, step: 1)
                    }
                    VStack(alignment: .leading) {
                        Text("Franja de pie: \(Int(settings.footerThresholdPercent)) %")
                            .font(.system(size: 11))
                        Slider(value: $settings.footerThresholdPercent, in: 2...20, step: 1)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 4)
    }
}

// MARK: - Actualizaciones

private struct UpdatesSettingsTab: View {
    @EnvironmentObject private var updater: UpdateService

    var body: some View {
        Form {
            Section("Versión instalada") {
                LabeledContent("LucentPDF", value: "\(updater.currentVersion) (build \(updater.buildNumber))")
            }

            Section("Comprobación de actualizaciones") {
                Toggle("Comprobar actualizaciones automáticamente",
                       isOn: $updater.automaticallyChecks)
                Button {
                    updater.checkForUpdates()
                } label: {
                    Label("Buscar actualizaciones ahora", systemImage: "arrow.down.circle")
                }
            }

            Section("Origen") {
                LabeledContent("Feed de actualizaciones") {
                    Text(updater.feedURLString)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Text("Las actualizaciones se distribuyen mediante Sparkle, fuera de la "
                    + "App Store. El instalador comprueba la firma de cada versión.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 4)
    }
}

// MARK: - Acerca de

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 14) {
            LogoMark(size: 84)
            HStack(spacing: 0) {
                Text("Lucent").foregroundStyle(Color.brandInk)
                Text("PDF").foregroundStyle(Color.brandBlue)
            }
            .font(.system(size: 26, weight: .bold))

            Text("Versión \(Bundle.main.shortVersion)")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Text("OCR por capas: Apple Vision + Tesseract")
                Text("Combina lotes de PDF en un documento buscable")
            }
            .font(.system(size: 11.5))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            BrandingView(fontSize: 12)

            Text("© 2026 LucentPDF")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }
}

private extension Bundle {
    var shortVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}
