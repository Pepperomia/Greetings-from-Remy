import SwiftUI

// MARK: - Glass Card Modifier

struct GlassCard: ViewModifier {
    // MARK: - Properties
    
    let radius: CGFloat
    let opacity: Double
    let hasShadow: Bool
    let hasStroke: Bool
    
    // MARK: - Body
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.regularMaterial)
                    .opacity(opacity)
            )
            .overlay(
                Group {
                    if hasStroke {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    }
                }
            )
            .shadow(
                color: hasShadow ? Color.black.opacity(0.1) : .clear,
                radius: hasShadow ? 8 : 0,
                x: 0,
                y: hasShadow ? 4 : 0
            )
    }
}

// MARK: - Extension

extension View {
    /// Применяет стеклянный стиль к карточке
    /// - Parameters:
    ///   - radius: радиус скругления (по умолчанию 22)
    ///   - opacity: прозрачность (по умолчанию 0.6)
    ///   - hasShadow: добавлять ли тень (по умолчанию true)
    ///   - hasStroke: добавлять ли обводку (по умолчанию true)
    /// - Returns: View со стеклянным стилем
    func glassCard(
        radius: CGFloat = 22,
        opacity: Double = 0.6,
        hasShadow: Bool = true,
        hasStroke: Bool = true
    ) -> some View {
        modifier(GlassCard(
            radius: radius,
            opacity: opacity,
            hasShadow: hasShadow,
            hasStroke: hasStroke
        ))
    }
}

// MARK: - Alternative Background Styles

struct UltraThinGlassCard: ViewModifier {
    let radius: CGFloat
    let hasShadow: Bool
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(
                color: hasShadow ? Color.black.opacity(0.1) : .clear,
                radius: 8,
                x: 0,
                y: 4
            )
    }
}

extension View {
    func ultraThinGlassCard(radius: CGFloat = 22, hasShadow: Bool = true) -> some View {
        modifier(UltraThinGlassCard(radius: radius, hasShadow: hasShadow))
    }
}

// MARK: - Interactive Card Modifier

struct InteractiveGlassCard: ViewModifier {
    let radius: CGFloat
    let opacity: Double
    
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.regularMaterial)
                    .opacity(opacity)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(
                        color: Color.black.opacity(0.1),
                        radius: isPressed ? 4 : 8,
                        x: 0,
                        y: isPressed ? 2 : 4
                    )
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .onTapGesture {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isPressed = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isPressed = false
                    }
                }
            }
    }
}

extension View {
    func interactiveGlassCard(radius: CGFloat = 22, opacity: Double = 0.6) -> some View {
        modifier(InteractiveGlassCard(radius: radius, opacity: opacity))
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppBackground()
        
        ScrollView {
            VStack(spacing: 20) {
                // Обычная стеклянная карточка
                Text("Обычная карточка")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .glassCard()
                    .padding(.horizontal)
                
                // Карточка с тенью и обводкой
                VStack(alignment: .leading, spacing: 8) {
                    Text("Заголовок")
                        .font(.title2.bold())
                    Text("Это пример карточки с настройками по умолчанию")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .glassCard(radius: 16, opacity: 0.7)
                .padding(.horizontal)
                
                // Ultra-thin карточка
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text("Ultra thin материал")
                        .font(.headline)
                }
                .padding()
                .ultraThinGlassCard(radius: 30)
                .padding(.horizontal)
                
                // Интерактивная карточка
                Text("Нажми на меня!")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .interactiveGlassCard()
                    .padding(.horizontal)
                
                // Карточка без тени
                Text("Без тени")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .glassCard(hasShadow: false)
                    .padding(.horizontal)
                
                // Карточка без обводки
                Text("Без обводки")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .glassCard(hasStroke: false)
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}
