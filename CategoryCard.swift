import SwiftUI
import UIKit

/// ОДНА карточка категории.
/// ВАЖНО: не объявляй CategoryCardRow больше нигде, иначе снова будет redeclaration.
struct CategoryCardRow: View {
    let title: String
    let subtitle: String
    let imageName: String?

    /// Единый «визуальный размер» картинок (чтобы все выглядели одинаково крупно)
    private let imageBox: CGSize = .init(width: 220, height: 140)

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 10)

            if let imageName, !imageName.isEmpty, UIImage(named: imageName) != nil {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: imageBox.width, height: imageBox.height)
                    // Компенсация «пустых полей» у некоторых картинок (чтобы все выглядели одинаково крупно)
                    .scaleEffect(1.18)
                    .offset(x: 10, y: 0)
                    .accessibilityLabel(Text(title))
            } else {
                Color.clear
                    .frame(width: imageBox.width, height: imageBox.height)
            }
        }
        .padding(.vertical, 14)     // плашки «поуже по вертикали»
        .padding(.horizontal, 16)
        .background(.white.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 10)
    }
}
