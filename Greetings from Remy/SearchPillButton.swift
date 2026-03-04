import SwiftUI

struct SearchPillButton: View {
    // MARK: - Properties
    
    let placeholder: String
    let onTap: () -> Void
    
    // MARK: - State
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    // MARK: - Body
    
    var body: some View {
        Button(action: {
            // Анимация нажатия
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                isPressed = true
            }
            
            // Тактильный отклик (опционально)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            // Действие
            onTap()
            
            // Возврат
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isPressed = false
                }
            }
        }) {
            HStack(spacing: 10) {
                // Лупа
                Image(systemName: "magnifyingglass")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                
                // Текст
                Text(placeholder)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                // Микрофон с анимацией пульсации
                Image(systemName: "mic.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary.opacity(0.8))
                    .scaleEffect(isHovered ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: isHovered
                    )
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: isPressed ? 4 : 8, x: 0, y: isPressed ? 2 : 4)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .onAppear {
            // Запускаем анимацию микрофона
            isHovered = true
        }
    }
}

// MARK: - Alternative Version (без микрофона)

struct SearchPillButtonSimple: View {
    let placeholder: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(placeholder)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(.regularMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppBackground()
        
        VStack(spacing: 20) {
            SearchPillButton(placeholder: "Найти рецепт...") {
                print("Поиск")
            }
            .padding(.horizontal, 20)
            
            SearchPillButtonSimple(placeholder: "Простой поиск") {
                print("Простой поиск")
            }
            .padding(.horizontal, 20)
        }
    }
}
