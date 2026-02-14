import SwiftUI

struct FavoritesView: View {
    @State private var items: [RecipeRow] = []
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                Group {
                    if items.isEmpty {
                        VStack(spacing: 12) {
                            Image("mouse_cheese") // ← твой ассет из Assets
                                .resizable()
                                .scaledToFit()
                                .frame(width: 140, height: 140)

                            Text("Пока пусто. Поставь сердечко на любимых рецептах ♥︎")
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 40)
                    } else {
                        List(items) { r in
                            NavigationLink {
                                RecipeDetailView(recipeId: r.id, title: r.title)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(r.title)
                                    HStack(spacing: 10) {
                                        Text("\(r.timeMinutes) мин")
                                        Text(diffLabel(r.difficulty))
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden) // ← чтобы фон был виден
                    }
                }
            }
            .navigationTitle("Избранное")
            .toolbar {
                Button("Обновить") { load() }
            }
            .onAppear { load() }
            .overlay {
                if let errorText {
                    Text("Ошибка: \(errorText)")
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding()
                }
            }
        }
    }

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
