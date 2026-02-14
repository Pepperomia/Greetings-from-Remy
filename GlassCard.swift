import SwiftUI

struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 8)
    }
}

extension View {
    func glassCard() -> some View { modifier(GlassCard()) }
}
