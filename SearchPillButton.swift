import SwiftUI

struct SearchPillButton: View {
    let placeholder: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                Text(placeholder)
                    .foregroundStyle(.secondary)

                Spacer()

                Image(systemName: "mic.fill")
                    .foregroundStyle(.secondary.opacity(0.8))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
