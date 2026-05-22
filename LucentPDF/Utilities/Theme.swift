import AppKit
import SwiftUI

/// Paleta de marca y estilos visuales reutilizables de LucentPDF.
extension Color {
    /// Índigo principal de la marca (#6E63FF).
    static let brandIndigo = Color(red: 0.431, green: 0.388, blue: 1.0)
    /// Azul intermedio (#4C7BF0).
    static let brandBlue = Color(red: 0.298, green: 0.482, blue: 0.941)
    /// Cian de acento (#21BDEB).
    static let brandCyan = Color(red: 0.129, green: 0.741, blue: 0.922)
    /// Tinta oscura para textos destacados (#1D2147).
    static let brandInk = Color(red: 0.114, green: 0.129, blue: 0.278)
}

enum Theme {
    /// Degradado diagonal de la marca.
    static let brandGradient = LinearGradient(
        colors: [.brandIndigo, .brandBlue, .brandCyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cornerRadius: CGFloat = 14
}

/// Estilo del botón de acción principal (degradado de marca).
struct PrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.brandGradient)
                    .opacity(enabled ? 1 : 0.4)
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Estilo de botón secundario (contorno suave).
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension View {
    /// Fondo tipo "tarjeta" para paneles de contenido.
    func cardBackground() -> some View {
        self.background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }
}
