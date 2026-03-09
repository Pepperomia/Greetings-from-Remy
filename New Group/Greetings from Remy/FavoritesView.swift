import SwiftUI

struct FavoritesView: View {

    @State private var items: [RecipeRow] = []
    @State private var isLoading = false
    @State private var errorText: String?

    var body: some View {

        NavigationStack {

            GeometryReader { geo in

                ZStack {

                    AppBackground(.list)

                    // HEADER
                    VStack {

                        header

                        Spacer()
                    }
                    .padding(.top, geo.safeAreaInsets.top)

                    // Если есть избранные рецепты, показываем их
                    if !items.isEmpty {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(items) { recipe in
                                    NavigationLink {
                                        RecipeDetailView(recipeId: recipe.id)
                                    } label: {
                                        favoriteRecipeRow(recipe)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 100)
                        }
                    } else {
                        // Отображаем красивый пустой экран только если нет избранных
                        // TOP MOUSE
                        topMouse
                            .position(
                                x: 70,
                                y: geo.safeAreaInsets.top + 52
                            )

                        // CENTER TEXT
                        centerText
                            .position(
                                x: geo.size.width / 2,
                                y: geo.size.height / 2
                            )

                        // BOTTOM MOUSE
                        bottomMouse
                            .position(
                                x: geo.size.width / 2,
                                y: geo.size.height - geo.safeAreaInsets.bottom - 84
                            )
                    }

                    // Индикатор загрузки
                    if isLoading {
                        ProgressView()
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    }

                    // Сообщение об ошибке
                    if let errorText = errorText {
                        Text(errorText)
                            .foregroundStyle(.red)
                            .font(.caption)
                            .position(x: geo.size.width / 2, y: geo.size.height - 100)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            loadFavorites()
        }
    }

    // MARK: HEADER

    private var header: some View {

        HStack {

            Text("Избранное")
                .font(.title2.bold())

            Spacer()

            // Показываем количество избранных рецептов, если они есть
            if !items.isEmpty {
                Text("\(items.count)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.regularMaterial)
                    )
            }
        }
        .padding(.horizontal, 124)
    }

    // MARK: TOP MOUSE

    private var topMouse: some View {

        Image("mouse_love")
            .resizable()
            .scaledToFit()
            .frame(width: 110)
    }

    // MARK: CENTER TEXT

    private var centerText: some View {

        VStack(spacing: 12) {

            Text("Пока пусто")
                .font(.headline)

            Text("Добавьте любимые рецепты")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: BOTTOM MOUSE

    private var bottomMouse: some View {

        Image("mouse_look")
            .resizable()
            .scaledToFit()
            .frame(width: 560)
    }

    // MARK: - Recipe Row for Favorites

    private func favoriteRecipeRow(_ recipe: RecipeRow) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    Label(recipe.timeText, systemImage: "clock")
                        .font(.caption)

                    if let calories = recipe.calories, calories > 0 {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Label("\(calories) ккал", systemImage: "flame")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text(recipe.difficultyText)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Добавляем маленькое сердечко для красоты
            Image(systemName: "heart.fill")
                .font(.caption2)
                .foregroundStyle(.red)
                .offset(x: -4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: DATA

    private func loadFavorites() {
        isLoading = true
        errorText = nil

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let favorites = try DatabaseManager.shared.fetchFavoriteRecipes()

                DispatchQueue.main.async {
                    self.items = favorites
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorText = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    FavoritesView()
}
