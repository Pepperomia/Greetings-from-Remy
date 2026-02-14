import SwiftUI

struct GlassCard: ViewModifier {
    let radius: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            // ❗️ВАЖНО: НИКАКОГО padding тут нет.
            // padding задаём в самой карточке (CategoryCard), чтобы высота управлялась.
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(opacity)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 14, x: 0, y: 8)
    }
}

extension View {
    func glassCard(radius: CGFloat = 22, opacity: Double = 0.60) -> some View {
        modifier(GlassCard(radius: radius, opacity: opacity))
    }
}
