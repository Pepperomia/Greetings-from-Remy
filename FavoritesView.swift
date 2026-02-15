import SwiftUI

struct FavoritesView: View {
    @State private var items: [RecipeRow] = []
    @State private var errorText: String?

    private enum UI {
        static let mouseLoveSize: CGFloat = 110
        static let headerTopPadding: CGFloat = 10
        static let headerSidePadding: CGFloat = 16

        static let cardRadius: CGFloat = 22
        static let cardOpacity: Double = 0.55
        static let cardVPadding: CGFloat = 14
        static let cardHPadding: CGFloat = 16
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {

                        headerRow

                        if let errorText {
                            Text("Ошибка: \(errorText)")
                                .padding()
                                .background(.thinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .padding(.horizontal)
                                .padding(.top, 6)
                        } else if items.isEmpty {
                            Text("Пока пусто 💛\nДобавь рецепты в избранное, и они появятся здесь.")
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                                .padding(.top, 18)
                                .padding(.horizontal)
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(items) { r in
                                    NavigationLink {
                                        RecipeDetailView(recipeId: r.id, title: r.title)
                                    } label: {
                                        FavoriteCardRow(
                                            title: r.title,
                                            subtitle: "\(r.timeMinutes) мин  •  \(diffLabel(r.difficulty))"
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.top, 6)
                            .padding(.bottom, 28)
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .tabBar)
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Обновить") { load() }
                }
            }
            .onAppear { load() }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 12) {
            MouseSticker("mouse_love", size: UI.mouseLoveSize)

            Text("Избранное")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, UI.headerSidePadding)
        .padding(.top, UI.headerTopPadding)
    }

    // MARK: - Data

    private func load() {
        do {
            errorText = nil
            items = try DatabaseManager.shared.fetchFavoriteRecipes()
        } catch {
            errorText = error.localizedDescription
            items = []
        }
    }

    private func diffLabel(_ diff: String) -> String {
        switch diff {
        case "easy": return "легко"
        case "hard": return "сложно"
        default: return "средне"
        }
    }
}

// MARK: - Card row

private struct FavoriteCardRow: View {
    let title: String
    let subtitle: String

    private enum UI {
        static let radius: CGFloat = 22
        static let opacity: Double = 0.55
        static let vPad: CGFloat = 14
        static let hPad: CGFloat = 16
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary.opacity(0.8))
        }
        .padding(.vertical, UI.vPad)
        .padding(.horizontal, UI.hPad)
        .glassCard(radius: UI.radius, opacity: UI.opacity)
    }
}

// MARK: - Mouse sticker helper
private struct MouseSticker: View {
    let name: String
    let size: CGFloat

    init(_ name: String, size: CGFloat) {
        self.name = name
        self.size = size
    }

    var body: some View {
        Image(name)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipped()
            .accessibilityHidden(true)
    }
}
