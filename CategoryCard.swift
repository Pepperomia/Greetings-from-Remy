import SwiftUI
import UIKit

struct CategoryCard: View {
    let title: String
    let subtitle: String
    let imageName: String?
    let imageSize: CGFloat

    // ✅ компактность карточки
    private let vPad: CGFloat = 10
    private let hPad: CGFloat = 16

    // ✅ прозрачность ТОЛЬКО фона карточки (0.18–0.55 обычно красиво)
    private let bgOpacity: Double = 0.32

    // ✅ скругление
    private let radius: CGFloat = 28

    var body: some View {
        HStack(spacing: 12) {

            // ТЕКСТ слева: занимает всё доступное, но не выталкивает картинку
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)                 // если не меняется — значит не этот файл используется
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // КАРТИНКА справа
            if let imageName, !imageName.isEmpty, UIImage(named: imageName) != nil {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: imageSize, height: imageSize)
                    .offset(x: 4, y: -2)
            }
        }
        .padding(.vertical, vPad)
        .padding(.horizontal, hPad)

        // ❗️ВАЖНО: НЕТ фиксированной высоты — карточка станет настолько низкой,
        // насколько позволит комбинация: текст + imageSize + паддинги.
        // Если хочешь ещё ниже — уменьшаем imageSize или vPad.

        .background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.ultraThinMaterial)
                // дополнительная “вуаль”, чтобы реально регулировать прозрачность
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(Color.white.opacity(bgOpacity))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 14, x: 0, y: 8)
    }
}
