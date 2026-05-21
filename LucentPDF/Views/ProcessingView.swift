import SwiftUI

/// Pantalla de procesamiento en curso, con progreso visible y cancelación.
struct ProcessingView: View {
    @EnvironmentObject private var viewModel: MainViewModel

    var body: some View {
        let progress = viewModel.progress

        VStack(spacing: 22) {
            Spacer()

            LogoMark(size: 76)

            Text("Procesando documentos")
                .font(.system(size: 19, weight: .bold))

            VStack(spacing: 8) {
                ProgressView(value: progress.fraction)
                    .progressViewStyle(.linear)
                    .tint(Color.brandBlue)

                HStack {
                    Text(progress.phase)
                    Spacer()
                    Text("\(Int(progress.fraction * 100)) %")
                        .monospacedDigit()
                }
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 460)

            if !progress.currentFileName.isEmpty {
                Label(progress.currentFileName, systemImage: "doc.text")
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 460)
            }

            HStack(spacing: 12) {
                StatCard(
                    icon: "doc.on.doc",
                    value: "\(progress.currentFileIndex) / \(progress.totalFiles)",
                    label: "documentos",
                    tint: .brandBlue)
                StatCard(
                    icon: "doc.text.magnifyingglass",
                    value: "\(progress.processedPages) / \(progress.totalPages)",
                    label: "páginas procesadas",
                    tint: .brandIndigo)
            }
            .frame(maxWidth: 460)

            Button(role: .cancel) {
                viewModel.cancelProcessing()
            } label: {
                Label("Cancelar procesamiento", systemImage: "stop.fill")
            }
            .buttonStyle(SecondaryButtonStyle())
            .padding(.top, 4)

            Text("Puedes cancelar en cualquier momento. La interfaz sigue activa.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
