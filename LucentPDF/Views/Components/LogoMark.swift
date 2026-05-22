import SwiftUI

/// El símbolo (icono) de LucentPDF, listo para usar en cualquier tamaño.
struct LogoMark: View {
    var size: CGFloat = 64

    var body: some View {
        Image("AppLogo")
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .accessibilityLabel("Logo de LucentPDF")
    }
}
