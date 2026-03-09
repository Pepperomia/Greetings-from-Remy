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
    
    // MARK: - Фильтр по кухням
    @State private var cuisines: [CuisineRow] = []
    @State private var selectedCuisineId: Int?
    
    @State private var isLoading = false
    
    @State private var originalItems: [RecipeRow] = []
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        
        ZStack {
            
            AppBackground(.list)
            
            ScrollView {
                
                VStack(spacing: 24) {
                    
                    filtersRow
                        .padding(.horizontal, 20)
                    
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
                    
                    // Кнопка управления удалением
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
            loadInitialData()
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
        .onChange(of: selectedCuisineId) { _, _ in
            applyCuisineFilter()
        }
    }
    
    // MARK: - Load Initial Data
    
    private func loadInitialData() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            // Сначала загружаем кухни
            self.loadCuisinesSync()
            
            // Потом загружаем рецепты
            self.loadRecipesSync()
        }
    }
    
    private func loadCuisinesSync() {
        do {
            let fetched = try DatabaseManager.shared.fetchAllCuisines()
            DispatchQueue.main.async {
                self.cuisines = fetched
            }
        } catch {
            print("Ошибка загрузки кухонь: \(error)")
        }
    }
    
    private func loadRecipesSync() {
        do {
            let maxMinutes = filter30 ? 30 : nil
            
            let recipes = try DatabaseManager.shared.fetchRecipes(
                categoryId: category.id,
                maxMinutes: maxMinutes
            )
            
            DispatchQueue.main.async {
                self.originalItems = recipes
                
                // Выводим информацию о кухнях для отладки
                for recipe in recipes {
                    print("📝 Рецепт: '\(recipe.title)', cuisineId: \(recipe.cuisineId?.description ?? "nil")")
                }
                
                // Применяем фильтр по кухне если выбран
                self.applyCuisineFilter()
                
                if self.sortByCalories {
                    self.sortRecipesByCalories()
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
    
    // MARK: - Apply Cuisine Filter
    
    private func applyCuisineFilter() {
        guard !originalItems.isEmpty else { return }
        
        if let cuisineId = selectedCuisineId {
            // Фильтруем рецепты по кухне
            items = originalItems.filter { $0.cuisineId == cuisineId }
            print("🎯 Отфильтровано по кухне \(cuisineId): \(items.count) рецептов")
        } else {
            items = originalItems
            print("🎯 Показаны все рецепты: \(items.count)")
        }
        
        if sortByCalories {
            sortRecipesByCalories()
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
        HStack(spacing: 20) {
            
            filterButton(
                image: "mouse_watch",
                title: "до 30 мин",
                isActive: filter30
            ) {
                filter30.toggle()
                loadRecipes()
            }
            
            filterButton(
                image: "mouse_cube",
                title: "Сюрприз",
                isActive: false
            ) {
                surpriseMe()
            }
            
            // Кнопка фильтра по кухням
            cuisineMenuButton
            
            filterButton(
                image: "mouse_weight",
                title: "Калории",
                isActive: sortByCalories
            ) {
                sortByCalories.toggle()
            }
        }
        .padding(.top, 16)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    func filterButton(
        image: String,
        title: String,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {

        Button(action: action) {
            VStack(spacing: 4) {
                Image(image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: 32)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(BounceButtonStyle())
        .opacity(isActive ? 0.6 : 1.0)
    }
    
    // MARK: - Cuisine Menu Button
    
    private var cuisineMenuButton: some View {
        Menu {
            Button("Все кухни") {
                selectedCuisineId = nil
            }
            
            if !cuisines.isEmpty {
                Divider()
                ForEach(cuisines) { cuisine in
                    Button(cuisine.name) {
                        selectedCuisineId = cuisine.id
                    }
                }
            }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .bottomTrailing) {
                    Image("mouse_world")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                    
                    if selectedCuisineId != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.mint)
                            .background(Circle().fill(.white))
                            .offset(x: 5, y: 5)
                    }
                }
                
                Text(selectedCuisineName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: 32)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(BounceButtonStyle())
    }
    
    private var selectedCuisineName: String {
        guard let id = selectedCuisineId,
              let cuisine = cuisines.first(where: { $0.id == id }) else {
            return "Кухня"
        }
        return cuisine.name
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
        
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            self.loadRecipesSync()
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
                    
                    // Сложность
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
    
    // Иконка сложности
    private var difficultyIcon: String {
        switch recipe.difficulty {
        case "easy": return "hand.thumbsup"
        case "hard": return "exclamationmark.triangle"
        default: return "equal"
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
