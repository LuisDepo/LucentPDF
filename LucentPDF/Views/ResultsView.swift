import SwiftUI

/// Pantalla de resultados: resumen, ubicación del PDF, incidencias y acciones.
struct ResultsView: View {
    @EnvironmentObject private var viewModel: MainViewModel

    var body: some View {
        if let report = viewModel.report {
            ScrollView {
                VStack(spacing: 18) {
                    hero(report)
                    statRow(report)
                    outputSection(report)
                    if !report.errors.isEmpty {
                        incidentsSection(report)
                    }
                    actions
                }
                .padding(24)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        } else {
            ScanningView()
        }
    }

    // MARK: - Secciones

    private func hero(_ report: ProcessingReport) -> some View {
        let hasIncidents = !report.errors.isEmpty
        return VStack(spacing: 10) {
            Image(systemName: hasIncidents
                ? "checkmark.seal.fill" : "checkmark.circle.fill")
                .font(.system(size: 46))
                .foregroundStyle(hasIncidents ? Color.orange : Color.green)
            Text(hasIncidents ? "Proceso completado con incidencias" : "¡Proceso completado!")
                .font(.system(size: 20, weight: .bold))
                .multilineTextAlignment(.center)
            Text(hasIncidents
                ? "El PDF final se generó con los documentos correctos. "
                    + "Revisa abajo los archivos con incidencias."
                : "Todos los documentos se combinaron en un PDF buscable.")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private func statRow(_ report: ProcessingReport) -> some View {
        HStack(spacing: 12) {
            StatCard(
                icon: "checkmark.circle",
                value: "\(report.successCount)",
                label: "archivos correctos",
                tint: .green)
            StatCard(
                icon: "exclamationmark.triangle",
                value: "\(report.partialCount + report.failedCount)",
                label: "con incidencias",
                tint: report.errors.isEmpty ? .secondary : .orange)
            StatCard(
                icon: "clock",
                value: Formatters.duration(report.duration),
                label: "tiempo total",
                tint: .brandIndigo)
            StatCard(
                icon: "doc.text.magnifyingglass",
                value: "\(report.totalOCRPages)",
                label: "páginas con OCR",
                tint: .brandBlue)
        }
    }

    @ViewBuilder
    private func outputSection(_ report: ProcessingReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "PDF final")

            if let outputURL = report.outputURL {
                HStack(spacing: 10) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.brandBlue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(outputURL.lastPathComponent)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(outputURL.deletingLastPathComponent().path)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Text(Formatters.fileSize(report.outputByteSize))
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    Button {
                        viewModel.openOutputPDF()
                    } label: {
                        Label("Abrir PDF", systemImage: "arrow.up.forward.app")
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button {
                        viewModel.revealOutputInFinder()
                    } label: {
                        Label("Mostrar en Finder", systemImage: "folder")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            } else {
                Text("El PDF se generó pero aún no se ha guardado.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Button {
                    viewModel.saveProcessedPDF()
                } label: {
                    Label("Guardar PDF…", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardBackground()
    }

    private func incidentsSection(_ report: ProcessingReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Incidencias por archivo (\(report.errors.count))")
            ForEach(report.errors) { outcome in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "doc")
                        .foregroundStyle(.secondary)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(outcome.relativePath)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if let detail = outcome.detail {
                            Text(detail)
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    StatusPill(text: outcome.status.displayName, color: outcome.status.tint)
                }
                .padding(.vertical, 4)
                if outcome.id != report.errors.last?.id {
                    Divider()
                }
            }
            Text("Se guardó un reporte de incidencias junto al PDF final.")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardBackground()
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.exportTechnicalLog()
            } label: {
                Label("Exportar log técnico", systemImage: "doc.badge.arrow.up")
            }
            .buttonStyle(SecondaryButtonStyle())

            Spacer()

            Button {
                viewModel.reset()
            } label: {
                Label("Procesar otra carpeta", systemImage: "arrow.clockwise")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(.top, 4)
    }
}
