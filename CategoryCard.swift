import SwiftUI

struct CategoryCard: View {
    let title: String
    let subtitle: String
    let imageName: String?
    let imageSize: CGFloat

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.2)) // ← Голубой фон для текста

            if let imageName, !imageName.isEmpty {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: imageSize, height: imageSize)
                    .background(Color.red.opacity(0.3)) // ← Красный фон для картинки
                    .offset(x: 4, y: -2)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(Color.green.opacity(0.1)) // ← Зеленый фон для всей карточки
        .border(Color.black, width: 2) // ← Черная рамка
    }
}
