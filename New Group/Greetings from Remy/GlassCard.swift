import SwiftUI

struct GlassCard<Content: View>: View {

    let radius: CGFloat
    let opacity: Double
    let hasShadow: Bool
    let hasStroke: Bool
    let content: Content

    init(
        radius: CGFloat = 24,
        opacity: Double = 0.3,
        hasShadow: Bool = true,
        hasStroke: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.radius = radius
        self.opacity = opacity
        self.hasShadow = hasShadow
        self.hasStroke = hasStroke
        self.content = content()
    }

    var body: some View {

        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(.ultraThinMaterial.opacity(opacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(hasStroke ? Color.white.opacity(0.2) : .clear)
            )
            .shadow(color: hasShadow ? .black.opacity(0.15) : .clear, radius: 10)
    }
}
extension View {

    func glassCard(
        radius: CGFloat = 24,
        opacity: Double = 0.3,
        hasShadow: Bool = true,
        hasStroke: Bool = true
    ) -> some View {

        GlassCard(
            radius: radius,
            opacity: opacity,
            hasShadow: hasShadow,
            hasStroke: hasStroke
        ) {
            self
        }
    }
}
