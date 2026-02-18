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
                    .lineLimit(2)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let imageName, !imageName.isEmpty {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: imageSize - 20, height: imageSize - 20) // ← уменьшили
                    .clipShape(RoundedRectangle(cornerRadius: 16)) // ← скруглили углы
                    .offset(x: 8, y: -2)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}
