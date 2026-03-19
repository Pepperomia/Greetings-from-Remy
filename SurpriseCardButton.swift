import SwiftUI

struct SurpriseCardButton: View {
    // MARK: - Properties
    
    let title: String
    let onTap: () -> Void
    
    // MARK: - State
    
    @State private var isPressed = false
    
    // MARK: - Body
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = true
            }
            
            // Тактильный отклик (опционально)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            // Выполняем действие
            onTap()
            
            // Возвращаем кнопку в исходное состояние
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isPressed = false
                }
            }
        }) {
            HStack(spacing: 12) {
                // Иконка
                Image("mouse_clover")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
                
                // Текст
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Стрелочка (добавила для интерактивности)
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .offset(x: isPressed ? 5 : 0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: isPressed ? 4 : 8, x: 0, y: isPressed ? 2 : 4)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppBackground()
        
        VStack {
            SurpriseCardButton(title: "Случайный рецепт") {
                print("Tapped!")
            }
            .padding(.horizontal, 20)
        }
    }
}
