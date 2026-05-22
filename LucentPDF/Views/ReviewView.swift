import SwiftUI

/// Pantalla de revisión: resultados del escaneo, orden y lista de archivos.
struct ReviewView: View {
    @EnvironmentObject private var viewModel: MainViewModel
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        if let summary = viewModel.scanSummary {
            VStack(spacing: 0) {
                header(summary)
                statRow(summary)
                controlRow
                fileList
                footer(summary)
            }
        } else {
            ScanningView()
        }
    }

    // MARK: - Secciones

    private func header(_ summary: ScanSummary) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Revisa los documentos")
                    .font(.system(size: 19, weight: .bold))
                Text(summary.rootURL.path)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button {
                viewModel.backToWelcome()
            } label: {
                Label("Elegir otra carpeta", systemImage: "chevron.left")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private func statRow(_ summary: ScanSummary) -> some View {
        HStack(spacing: 12) {
            StatCard(
                icon: "doc.on.doc",
                value: "\(summary.fileCount)",
                label: "archivos PDF",
                tint: .brandBlue)
            StatCard(
                icon: "doc.text.magnifyingglass",
                value: "\(summary.totalPages)",
                label: "páginas estimadas",
                tint: .brandIndigo)
            StatCard(
                icon: "externaldrive",
                value: Formatters.fileSize(summary.totalBytes),
                label: "peso total",
                tint: .brandCyan)
            StatCard(
                icon: "folder",
                value: "\(summary.directories.count)",
                label: "subcarpetas",
                tint: .green)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 14)
    }

    private var controlRow: some View {
        HStack(spacing: 12) {
            Picker("Orden de combinación", selection: Binding(
                get: { settings.sortStrategy },
                set: { viewModel.applySortStrategy($0) }
            )) {
                ForEach(SortStrategy.allCases) { strategy in
                    Text(strategy.displayName).tag(strategy)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()

            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
                .help(settings.sortStrategy.explanation)

            Spacer()

            Text(optionsSummary)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    private var fileList: some View {
        List {
            ForEach(Array(viewModel.displayedFiles.enumerated()), id: \.element.id) { index, file in
                FileRow(index: index + 1, file: file)
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .frame(maxHeight: .infinity)
    }

    private func footer(_ summary: ScanSummary) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Label(
                    "Se aplicará OCR y se generará un único PDF buscable.",
                    systemImage: "sparkles")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    viewModel.startProcessing()
                } label: {
                    Label("Procesar \(Formatters.fileCount(summary.fileCount))",
                          systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
    }

    private var optionsSummary: String {
        var parts: [String] = []
        var languages: [String] = []
        if settings.recognizeSpanish { languages.append("ES") }
        if settings.recognizeEnglish { languages.append("EN") }
        parts.append("OCR: " + (languages.isEmpty ? "ES·EN" : languages.joined(separator: "·")))
        parts.append("\(settings.rasterDPI) ppp")
        if settings.skipDigitalText { parts.append("omite texto digital") }
        if settings.excludeHeadersFooters { parts.append("sin encabezados/pies") }
        return parts.joined(separator: "  ·  ")
    }
}

/// Fila de la lista de archivos.
struct FileRow: View {
    let index: Int
    let file: PDFFileItem

    var body: some View {
        HStack(spacing: 10) {
            Text("\(index)")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .trailing)

            Image(systemName: "doc.richtext")
                .foregroundStyle(Color.brandBlue)

            VStack(alignment: .leading, spacing: 1) {
                Text(file.fileName)
                    .font(.system(size: 12.5))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !file.relativeDirectory.isEmpty {
                    Text(file.relativeDirectory)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }

            Spacer()

            Text(Formatters.pageCount(file.pageCount))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 84, alignment: .trailing)

            Text(Formatters.fileSize(file.byteSize))
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 74, alignment: .trailing)
        }
        .padding(.vertical, 3)
    }
}
