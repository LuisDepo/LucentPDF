import SwiftUI

/// Pantalla inicial: logo, nombre del producto y acción para elegir carpeta.
struct WelcomeView: View {
    @EnvironmentObject private var viewModel: MainViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            VStack(spacing: 20) {
                LogoMark(size: 104)

                VStack(spacing: 6) {
                    HStack(spacing: 0) {
                        Text("Lucent").foregroundStyle(Color.brandInk)
                        Text("PDF").foregroundStyle(Color.brandBlue)
                    }
                    .font(.system(size: 34, weight: .bold))

                    Text("Une tus PDF escaneados en un único documento buscable")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                Text("Elige una carpeta: LucentPDF buscará todos los PDF dentro de ella "
                    + "y de sus subcarpetas, les aplicará OCR de alta calidad y los "
                    + "combinará en un solo archivo con texto que se puede buscar y copiar.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 470)

                Button {
                    viewModel.chooseFolder()
                } label: {
                    Label("Seleccionar carpeta", systemImage: "folder")
                }
                .buttonStyle(PrimaryButtonStyle())

                Label("También puedes arrastrar una carpeta a esta ventana",
                      systemImage: "hand.draw")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)

                if let error = viewModel.scanError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 470)
                }
            }
            .padding(36)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        Color.primary.opacity(0.12),
                        style: StrokeStyle(lineWidth: 1.5, dash: [7, 5])
                    )
            )

            Spacer(minLength: 24)

            orderingNote
                .padding(.bottom, 14)

            BrandingView(fontSize: 12)
                .padding(.bottom, 18)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var orderingNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(Color.brandBlue)
            Text("Los documentos se combinan por ruta de carpeta y nombre. "
                + "Podrás revisar y cambiar el orden antes de procesar.")
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 11.5))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Capsule().fill(Color.brandBlue.opacity(0.08))
        )
    }
}
