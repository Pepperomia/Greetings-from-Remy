import SwiftUI

// MARK: - Универсальный модификатор для анимации карточек
struct CardAnimation: ViewModifier {
    @State private var isPressed = false
    var scaleFactor: CGFloat = 0.98
    var animationDuration: Double = 0.2
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scaleFactor : 1.0)
            .animation(.spring(response: animationDuration, dampingFraction: 0.7), value: isPressed)
            .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
                withAnimation(.spring(response: animationDuration, dampingFraction: 0.7)) {
                    isPressed = pressing
                }
            }, perform: {})
    }
}

// MARK: - Модификатор для NavigationLink карточек
struct CardButtonStyle: ButtonStyle {
    var scaleFactor: CGFloat = 0.98
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleFactor : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Расширение View для удобного использования
extension View {
    /// Добавляет анимацию нажатия на карточку
    /// - Parameter scaleFactor: коэффициент уменьшения при нажатии (по умолчанию 0.98)
    /// - Returns: View с анимацией
    func cardAnimation(scaleFactor: CGFloat = 0.98) -> some View {
        modifier(CardAnimation(scaleFactor: scaleFactor))
    }
    
    /// Добавляет свечение при нажатии
    /// - Parameter color: цвет свечения
    /// - Returns: View с эффектом свечения
    func glowOnPress(color: Color = .blue) -> some View {
        self.modifier(GlowOnPress(color: color))
    }
}

// MARK: - Модификатор для свечения
struct GlowOnPress: ViewModifier {
    @State private var isPressed = false
    var color: Color
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(color.opacity(isPressed ? 0.5 : 0), lineWidth: 2)
                    .scaleEffect(isPressed ? 1.02 : 1.0)
            )
            .shadow(color: color.opacity(isPressed ? 0.3 : 0), radius: isPressed ? 10 : 0)
            .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPressed = pressing
                }
            }, perform: {})
    }
}

// MARK: - Комбинированный модификатор для полного эффекта
struct CompleteCardAnimation: ViewModifier {
    @State private var isPressed = false
    var scaleFactor: CGFloat = 0.98
    var glowColor: Color = .blue
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scaleFactor : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(glowColor.opacity(isPressed ? 0.5 : 0), lineWidth: 2)
            )
            .shadow(color: glowColor.opacity(isPressed ? 0.3 : 0), radius: isPressed ? 10 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
            .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isPressed = pressing
                }
            }, perform: {})
    }
}

extension View {
    /// Полная анимация карточки (уменьшение + свечение + тень)
    func completeCardAnimation(scaleFactor: CGFloat = 0.98, glowColor: Color = .blue) -> some View {
        modifier(CompleteCardAnimation(scaleFactor: scaleFactor, glowColor: glowColor))
    }
}
