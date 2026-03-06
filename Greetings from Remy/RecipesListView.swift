import SwiftUI

struct RecipesListView: View {

    let category: CategoryRow

    @State private var items: [RecipeRow] = []
    @State private var errorText: String?

    @State private var filter30 = false
    @State private var sortByCalories = false // Новый state для сортировки по калориям
    @State private var surpriseRecipeId: Int?

    @State private var isLoading = false
    
    // Сохраняем оригинальные данные для сброса сортировки
    @State private var originalItems: [RecipeRow] = []

    var body: some View {

        ZStack {

            AppBackground(.list)

            ScrollView {

                VStack(spacing: 24) {

                    filtersRow

                    if isLoading {

                        ProgressView()
                            .padding(.top, 40)

                    } else if let errorText {

                        errorView(errorText)

                    } else if items.isEmpty {

                        emptyView

                    } else {

                        recipesList
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(category.displayName)
        .navigationBarTitleDisplayMode(.inline)

        .navigationDestination(isPresented: surpriseBinding) {
            if let id = surpriseRecipeId {
                RecipeDetailView(recipeId: id)
            }
        }

        .onAppear {
            loadRecipes()
        }

        .onChange(of: filter30) { _, _ in
            loadRecipes()
        }
        
        .onChange(of: sortByCalories) { _, newValue in
            if newValue {
                sortRecipesByCalories()
            } else {
                // Возвращаем оригинальный порядок
                items = originalItems
            }
        }
    }
}

////////////////////////////////////////////////////////////
// MARK: Bindings
////////////////////////////////////////////////////////////

private extension RecipesListView {

    var surpriseBinding: Binding<Bool> {
        Binding(
            get: { surpriseRecipeId != nil },
            set: { if !$0 { surpriseRecipeId = nil } }
        )
    }
}

////////////////////////////////////////////////////////////
// MARK: Filters
////////////////////////////////////////////////////////////

private extension RecipesListView {

    var filtersRow: some View {

        HStack(spacing: 36) {

            filterButton(
                image: "mouse_watch",
                title: "до 30 мин",
                isActive: filter30
            ) {
                filter30.toggle()
            }

            filterButton(
                image: "mouse_cube",
                title: "Сюрприз",
                isActive: false // Сюрприз всегда яркий (неактивное состояние = яркий)
            ) {
                surpriseMe()
            }
            
            // Новая кнопка для сортировки по калориям
            filterButton(
                image: "mouse_weight",
                title: "Калории",
                isActive: sortByCalories
            ) {
                sortByCalories.toggle()
            }
        }
        .padding(.top, 16)
    }

    func filterButton(
        image: String,
        title: String,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {

        Button(action: action) {

            VStack(spacing: 8) {

                Image(image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90, height: 90)

                Text(title)
                    .font(.caption)
            }
        }
        .buttonStyle(BounceButtonStyle())
        // Инвертируем логику: яркие по умолчанию, бледнеют при активации
        .opacity(isActive ? 0.6 : 1.0)
    }
}

////////////////////////////////////////////////////////////
// MARK: List
////////////////////////////////////////////////////////////

private extension RecipesListView {

    var recipesList: some View {

        LazyVStack(spacing: 16) {

            ForEach(items) { recipe in

                NavigationLink {

                    RecipeDetailView(recipeId: recipe.id)

                } label: {

                    RecipeCardRow(recipe: recipe)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }

    var emptyView: some View {

        Text("Нет рецептов")
            .padding(.top, 40)
    }

    func errorView(_ text: String) -> some View {

        Text(text)
            .foregroundStyle(.red)
            .padding(.top, 40)
    }
}

////////////////////////////////////////////////////////////
// MARK: Data
////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////
// MARK: Data
////////////////////////////////////////////////////////////

private extension RecipesListView {

    func loadRecipes() {

        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {

            do {

                let maxMinutes = filter30 ? 30 : nil

                let recipes = try DatabaseManager.shared.fetchRecipes(
                    categoryId: category.id,
                    maxMinutes: maxMinutes
                )

                DispatchQueue.main.async {

                    // ТЕСТ: добавляем случайные калории для проверки отображения
                    let testRecipes = recipes.map { recipe -> RecipeRow in
                        // Создаем новый рецепт с тестовыми калориями
                        return RecipeRow(
                            id: recipe.id,
                            title: recipe.title,
                            timeMinutes: recipe.timeMinutes,
                            difficulty: recipe.difficulty,
                            calories: Int.random(in: 100...800) // Случайные калории
                        )
                    }
                    
                    self.originalItems = testRecipes
                    self.items = testRecipes
                    
                    // ОТЛАДКА: посмотрим, есть ли калории
                    for recipe in testRecipes {
                        print("Рецепт: \(recipe.title), калории: \(recipe.calories?.description ?? "nil")")
                    }
                    
                    if self.sortByCalories {
                        self.sortRecipesByCalories() // Теперь这个方法 существует
                    }
                    
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
    
    // Добавляем метод сортировки по калориям
    func sortRecipesByCalories() {
        items.sort { recipe1, recipe2 in
            let calories1 = recipe1.calories ?? 0
            let calories2 = recipe2.calories ?? 0
            return calories1 < calories2 // от меньшего к большему
        }
    }

    func surpriseMe() {

        guard !items.isEmpty else { return }

        surpriseRecipeId = items.randomElement()?.id
    }
}

////////////////////////////////////////////////////////////
// MARK: Card
////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////
// MARK: Card
////////////////////////////////////////////////////////////

private struct RecipeCardRow: View {

    let recipe: RecipeRow

    var body: some View {

        HStack {

            VStack(alignment: .leading, spacing: 8) {

                Text(recipe.title)
                    .font(.headline)

                HStack(spacing: 10) {
                    Text(recipe.timeText)
                    
                    if let calories = recipe.calories, calories > 0 {
                        Text("•")
                        Text("\(calories) ккал")
                            .foregroundStyle(.orange)
                    }
                    
                    if !recipe.timeText.isEmpty && !recipe.difficultyText.isEmpty {
                        Text("•")
                    }
                    
                    Text(recipe.difficultyText)
                }
                
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial)
        )
        .shadow(
            color: .black.opacity(0.12),
            radius: 12,
            y: 6
        )
    }
}
////////////////////////////////////////////////////////////
// MARK: Button animation
////////////////////////////////////////////////////////////

struct BounceButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {

        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25), value: configuration.isPressed)
    }
    
}
