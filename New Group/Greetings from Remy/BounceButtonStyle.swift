import SwiftUI

struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25), value: configuration.isPressed)
    }
}

// Для удобного использования
extension ButtonStyle where Self == BounceButtonStyle {
    static var bounce: BounceButtonStyle {
        BounceButtonStyle()
    }
}
