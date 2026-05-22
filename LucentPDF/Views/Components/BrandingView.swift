import SwiftUI

/// Firma de marca «LucentPDF by [logo]».
///
/// El logo (`ByLogo` en el catálogo de assets) se muestra al **150 %** del
/// tamaño de la fuente del texto, según el requisito de marca. Para usar un
/// logo propio basta con sustituir las imágenes del set `ByLogo.imageset`.
struct BrandingView: View {
    var fontSize: CGFloat = 13

    var body: some View {
        HStack(spacing: 6) {
            Text("LucentPDF by")
                .font(.system(size: fontSize, weight: .medium))
                .foregroundStyle(.secondary)
            Image("ByLogo")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: fontSize * 1.5, height: fontSize * 1.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("LucentPDF by")
    }
}

/// Logotipo horizontal: símbolo + nombre del producto.
struct WordmarkView: View {
    var symbolSize: CGFloat = 34
    var fontSize: CGFloat = 24

    var body: some View {
        HStack(spacing: 10) {
            LogoMark(size: symbolSize)
            HStack(spacing: 0) {
                Text("Lucent").foregroundStyle(Color.brandInk)
                Text("PDF").foregroundStyle(Color.brandBlue)
            }
            .font(.system(size: fontSize, weight: .bold))
        }
    }
}
