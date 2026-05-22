import SwiftUI

/// Tarjeta de estadística (icono + valor + etiqueta).
struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    var tint: Color = .brandBlue

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardBackground()
    }
}

/// Indicador de estado en forma de "pastilla".
struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(color.opacity(0.14))
            )
    }
}

extension FileOutcomeStatus {
    var tint: Color {
        switch self {
        case .success: return .green
        case .skippedText: return .brandBlue
        case .partial: return .orange
        case .failed: return .red
        }
    }
}

/// Encabezado de sección sencillo.
struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}
