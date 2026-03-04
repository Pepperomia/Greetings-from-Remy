import SwiftUI

struct CategoryCard: View {
    // MARK: - Properties
    
    let title: String
    let subtitle: String
    let imageName: String?
    let imageSize: CGFloat
    
    // MARK: - State
    
    @State private var isPressed = false
    
    // MARK: - Constants
    
    private let cornerRadius: CGFloat = 24
    private let imageCornerRadius: CGFloat = 16
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 12) {
            // Текстовая часть
            textContent
            
            Spacer()
            
            // Картинка
            if let imageName = imageName, !imageName.isEmpty {
                categoryImage(imageName)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(
                    color: .black.opacity(0.1),
                    radius: isPressed ? 4 : 8,
                    x: 0,
                    y: isPressed ? 2 : 4
                )
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
    
    // MARK: - Text Content
    
    private var textContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Category Image
    
    private func categoryImage(_ name: String) -> some View {
        Image(name)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: imageSize - 16, height: imageSize - 16)
            .clipShape(RoundedRectangle(cornerRadius: imageCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: imageCornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .offset(x: 4, y: -2)
    }
}

// MARK: - Alternative Grid Version

struct CategoryGridCard: View {
    let title: String
    let subtitle: String
    let imageName: String?
    let size: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Изображение
            if let imageName = imageName, !imageName.isEmpty {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.regularMaterial)
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "fork.knife")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    )
            }
            
            // Текст
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppBackground()
        
        ScrollView {
            VStack(spacing: 16) {
                CategoryCard(
                    title: "Завтраки",
                    subtitle: "Быстрый старт дня • 108 рецептов",
                    imageName: "cat_breakfasts",
                    imageSize: 80
                )
                .padding(.horizontal, 16)
                
                CategoryCard(
                    title: "Салаты",
                    subtitle: "Свежие и сытные • 54 рецепта",
                    imageName: "cat_salads",
                    imageSize: 80
                )
                .padding(.horizontal, 16)
                
                Divider()
                    .padding(.horizontal, 16)
                
                Text("Grid Version")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    CategoryGridCard(
                        title: "Завтраки",
                        subtitle: "108 рецептов",
                        imageName: "cat_breakfasts",
                        size: 120
                    )
                    
                    CategoryGridCard(
                        title: "Салаты",
                        subtitle: "54 рецепта",
                        imageName: "cat_salads",
                        size: 120
                    )
                    
                    CategoryGridCard(
                        title: "Супы",
                        subtitle: "50 рецептов",
                        imageName: "cat_soups",
                        size: 120
                    )
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 20)
        }
    }
}
