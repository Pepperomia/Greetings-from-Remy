import SwiftUI

struct RecipesListView: View {

    let category: CategoryRow

    @State private var items: [RecipeRow] = []
    @State private var errorText: String?
    @State private var showingDeleteAlert = false
    @State private var isDeleting = false
    @State private var showingDeleteManagement = false

    @State private var filter30 = false
    @State private var sortByCalories = false
    @State private var surpriseRecipeId: Int?

    @State private var isLoading = false
    
    @State private var originalItems: [RecipeRow] = []
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {

        ZStack {

            AppBackground(.list)

            ScrollView {

                VStack(spacing: 24) {

                    filtersRow

                    if isLoading {

                        ProgressView()
                            .padding(.top, 40)

                    } else if let errorText = errorText {

                        errorView(errorText: errorText)

                    } else if items.isEmpty {

                        emptyView()

                    } else {

                        recipesList
                    }
                    
                    // Кнопка управления удалением - всегда внизу
                    deleteManagementButton
                        .padding(.top, 20)
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
        .alert("Удаление категории", isPresented: $showingDeleteAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Удалить", role: .destructive) {
                deleteCategory()
            }
        } message: {
            Text("Вы уверены, что хотите удалить категорию «\(category.displayName)»?")
        }
        .sheet(isPresented: $showingDeleteManagement) {
            DeleteManagementView()
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
                items = originalItems
            }
        }
    }
    
    // MARK: - Delete Management Button
    
    private var deleteManagementButton: some View {
        Button {
            showingDeleteManagement = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Управление удалением")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.regularMaterial)
            .foregroundColor(.red)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Delete Category Button
    
    private var deleteCategoryButton: some View {
        Button(action: {
            showingDeleteAlert = true
        }) {
            HStack {
                if isDeleting {
                    ProgressView()
                        .tint(.red)
                } else {
                    Image(systemName: "trash")
                }
                Text("Удалить категорию")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.regularMaterial)
            .foregroundColor(.red)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(isDeleting)
    }
    
    // MARK: - Delete Category Function
    
    private func deleteCategory() {
        isDeleting = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try DatabaseManager.shared.deleteCategory(id: category.id)
                
                DispatchQueue.main.async {
                    isDeleting = false
                    dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    errorText = error.localizedDescription
                    isDeleting = false
                    showingDeleteAlert = false
                }
            }
        }
    }
    
    // MARK: - View Builders
    
    func errorView(errorText: String) -> some View {
        Text(errorText)
            .foregroundStyle(.red)
            .padding(.top, 40)
    }
    
    func emptyView() -> some View {
        VStack(spacing: 20) {
            Text("В этой категории нет рецептов")
                .foregroundStyle(.secondary)
                .padding(.top, 40)
            
            // Кнопка удаления пустой категории
            deleteCategoryButton
        }
    }
}

// MARK: Bindings
private extension RecipesListView {
    var surpriseBinding: Binding<Bool> {
        Binding(
            get: { surpriseRecipeId != nil },
            set: { if !$0 { surpriseRecipeId = nil } }
        )
    }
}

// MARK: Filters
private extension RecipesListView {

    var filtersRow: some View {

        HStack(spacing: 25) {

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
                isActive: false
            ) {
                surpriseMe()
            }
            
            filterButton(
                image: "mouse_weight",
                title: "Калории",
                isActive: sortByCalories
            ) {
                sortByCalories.toggle()
            }
        }
        .padding(.top, 16)
        .frame(maxWidth: .infinity)
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
                    .frame(width: 110, height: 110)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(BounceButtonStyle())
        .opacity(isActive ? 0.6 : 1.0)
    }
}

// MARK: List
private extension RecipesListView {

    var recipesList: some View {

        LazyVStack(spacing: 16) {

            ForEach(items) { recipe in
                NavigationLink {
                    RecipeDetailView(recipeId: recipe.id)
                } label: {
                    RecipeCardRow(recipe: recipe)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                        .completeCardAnimation(glowColor: .orange)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.top, 8)
    }
}

// MARK: Data
private extension RecipesListView {

    func loadRecipes() {
        isLoading = true
        print("🔄 Загрузка рецептов для категории: \(category.name)")

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let maxMinutes = filter30 ? 30 : nil
                print("🔄 Фильтр до 30 мин: \(maxMinutes != nil)")

                let recipes = try DatabaseManager.shared.fetchRecipes(
                    categoryId: category.id,
                    maxMinutes: maxMinutes
                )
                
                print("🔄 Получено рецептов из БД: \(recipes.count)")

                DispatchQueue.main.async {
                    // Используем реальные данные из базы без изменений
                    self.originalItems = recipes
                    self.items = recipes
                    
                    // Подробная отладка для каждого рецепта
                    for recipe in recipes {
                        print("📝 Рецепт: '\(recipe.title)'")
                        print("   - время: \(recipe.timeMinutes) мин")
                        print("   - сложность: \(recipe.difficulty)")
                        print("   - калории из БД: \(recipe.calories?.description ?? "nil")")
                        print("   - калории для отображения: \(recipe.calories != nil && recipe.calories! > 0 ? "\(recipe.calories!) ккал" : "нет данных")")
                    }
                    
                    // Проверяем, есть ли вообще рецепты с калориями
                    let recipesWithCalories = recipes.filter { $0.calories != nil && $0.calories! > 0 }
                    print("📊 Рецептов с калориями: \(recipesWithCalories.count) из \(recipes.count)")
                    
                    if self.sortByCalories {
                        self.sortRecipesByCalories()
                    }
                    
                    self.isLoading = false
                }
            } catch {
                print("❌ Ошибка загрузки: \(error)")
                DispatchQueue.main.async {
                    self.errorText = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    func sortRecipesByCalories() {
        items.sort { recipe1, recipe2 in
            let calories1 = recipe1.calories ?? 0
            let calories2 = recipe2.calories ?? 0
            return calories1 < calories2
        }
        print("📊 Рецепты отсортированы по калориям")
    }

    func surpriseMe() {
        guard !items.isEmpty else { return }
        surpriseRecipeId = items.randomElement()?.id
        print("🎲 Случайный рецепт: id \(surpriseRecipeId ?? 0)")
    }
}

// MARK: Card
private struct RecipeCardRow: View {

    let recipe: RecipeRow

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(recipe.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    // Время
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(recipe.timeText)
                            .font(.caption)
                    }
                    
                    // Разделитель
                    Text("•")
                        .foregroundStyle(.secondary)
                    
                    // Сложность с иконкой (исправлено на доступные иконки)
                    HStack(spacing: 4) {
                        Image(systemName: difficultyIcon)
                            .font(.caption2)
                        Text(recipe.difficultyText)
                            .font(.caption)
                    }
                    
                    // Калории (если есть)
                    if let calories = recipe.calories, calories > 0 {
                        Text("•")
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "flame")
                                .font(.caption2)
                                .foregroundStyle(caloriesColor(calories))
                            Text("\(calories) ккал")
                                .font(.caption)
                                .foregroundStyle(caloriesColor(calories))
                        }
                    }
                }
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .opacity(0.7)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(
            color: .black.opacity(0.1),
            radius: 15,
            x: 0,
            y: 8
        )
    }
    
    // Иконка сложности (исправлено на доступные иконки)
    private var difficultyIcon: String {
        switch recipe.difficulty {
        case "easy": return "hand.thumbsup"  // было face.smiling
        case "hard": return "exclamationmark.triangle"  // было face.dashed
        default: return "equal"  // было face.neutral
        }
    }
    
    // Цвет калорий в зависимости от значения
    private func caloriesColor(_ calories: Int) -> Color {
        switch calories {
        case 0..<200: return .green
        case 200..<400: return .orange
        default: return .red
        }
    }
}
