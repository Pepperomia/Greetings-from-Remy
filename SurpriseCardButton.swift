import SwiftUI

struct SurpriseCardButton: View {
    let title: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image("mouse_clover")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
