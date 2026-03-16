import SwiftUI

struct RecipesListView: View {

    let category: CategoryRow

    @State private var items: [RecipeRow] = []
    @State private var filteredItems: [RecipeRow] = []
    @State private var errorText: String?
    @State private var showingDeleteAlert = false
    @State private var isDeleting = false
    @State private var showingDeleteManagement = false

    @State private var filter30 = false
    @State private var sortByCalories = false
    @State private var surpriseRecipeId: Int?
    
    // MARK: - Поиск по названию
    @State private var searchText = ""
    
    // MARK: - Фильтр по кухням
    @State private var cuisines: [CuisineRow] = []
    @State private var selectedCuisineId: Int?

    @State private var isLoading = false
    
    @State private var originalItems: [RecipeRow] = []
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Constants
    private let buttonSize: CGFloat = 80 // Размер кнопок как в SearchView
    
    // MARK: - Computed Properties
    
    private var hasActiveFilters: Bool {
        filter30 || sortByCalories || selectedCuisineId != nil || !searchText.isEmpty
    }

    var body: some View {

        ZStack {

            AppBackground(.list)

            ScrollView {

                VStack(spacing: 20) {

                    // Поиск
                    searchField
                        .padding(.horizontal, 16)
                    
                    // Фильтры в одну строку (как в SearchView)
                    filtersRow
                        .padding(.horizontal, 8)

                    if isLoading {

                        ProgressView()
                            .padding(.top, 40)

                    } else if let errorText = errorText {

                        errorView(errorText: errorText)
                            .padding(.horizontal, 8)

                    } else if filteredItems.isEmpty {

                        emptyView()
                            .padding(.horizontal, 8)

                    } else {

                        resultsSection
                            .padding(.horizontal, 8)
                    }
                    
                    // Кнопка управления удалением
                    if !hasActiveFilters {
                        deleteManagementButton
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
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
            applyFilters()
        }
        .onChange(of: sortByCalories) { _, _ in
            applyFilters()
        }
        .onChange(of: selectedCuisineId) { _, _ in
            applyFilters()
        }
        .onChange(of: searchText) { _, _ in
            applyFilters()
        }
    }
    
    // MARK: - Search Field
    
    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.headline)
            
            TextField("Поиск по названию...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.body)
                .onSubmit {
                    applyFilters()
                }
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.headline)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Load Initial Data
    
    private func loadInitialData() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            self.loadCuisinesSync()
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
                self.applyFilters()
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorText = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Apply All Filters
    
    private func applyFilters() {
        guard !originalItems.isEmpty else { return }
        
        var filtered = originalItems
        
        if filter30 {
            filtered = filtered.filter { $0.timeMinutes <= 30 }
        }
        
        if let cuisineId = selectedCuisineId {
            filtered = filtered.filter { $0.cuisineId == cuisineId }
        }
        
        if !searchText.isEmpty {
            let searchQuery = searchText.lowercased()
            filtered = filtered.filter { $0.title.lowercased().contains(searchQuery) }
        }
        
        filteredItems = filtered
        
        if sortByCalories {
            filteredItems.sort { $0.calories ?? 0 < $1.calories ?? 0 }
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
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
            )
            .foregroundColor(.red)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
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
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
            )
            .foregroundColor(.red)
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
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
    }
    
    func emptyView() -> some View {
        VStack(spacing: 20) {
            if !searchText.isEmpty || hasActiveFilters {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 50))
                    .foregroundStyle(.secondary)
                
                Text("Ничего не найдено")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                Text("Попробуйте изменить параметры поиска")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                Button("Сбросить фильтры") {
                    resetFilters()
                }
                .font(.headline)
                .foregroundStyle(.mint)
                .padding(.top, 8)
                
            } else {
                Text("В этой категории нет рецептов")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)
                
                deleteCategoryButton
                    .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func resetFilters() {
        searchText = ""
        filter30 = false
        sortByCalories = false
        selectedCuisineId = nil
        applyFilters()
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
        HStack(spacing: 12) {
            
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
            
            cuisineMenuButton
            
            filterButton(
                image: "mouse_weight",
                title: "Калории",
                isActive: sortByCalories
            ) {
                sortByCalories.toggle()
            }
            
            if hasActiveFilters {
                resetFilterButton
            }
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity)
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
                    .frame(width: buttonSize, height: buttonSize)
                
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
                        .frame(width: buttonSize, height: buttonSize)
                    
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
    
    private var resetFilterButton: some View {
        Button {
            resetFilters()
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: buttonSize, height: buttonSize)
                    
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                
                Text("Сброс")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .frame(height: 32)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(BounceButtonStyle())
    }
}

// MARK: Results Section
private extension RecipesListView {

    var resultsSection: some View {
        VStack(spacing: 12) {
            // Заголовок по центру
            HStack {
                Spacer()
                
                VStack(spacing: 2) {
                    Text("Результаты")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("\(filteredItems.count) \(recipeWord(for: filteredItems.count))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
            
            // Карточки рецептов
            LazyVStack(spacing: 12) {
                ForEach(filteredItems) { recipe in
                    NavigationLink {
                        RecipeDetailView(recipeId: recipe.id)
                    } label: {
                        RecipeCardRow(recipe: recipe)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private func recipeWord(for count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        
        if mod10 == 1 && mod100 != 11 {
            return "рецепт"
        } else if mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20) {
            return "рецепта"
        } else {
            return "рецептов"
        }
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

    func surpriseMe() {
        guard !filteredItems.isEmpty else { return }
        surpriseRecipeId = filteredItems.randomElement()?.id
    }
}

// MARK: Card
private struct RecipeCardRow: View {

    let recipe: RecipeRow

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                
                HStack(spacing: 6) {
                    // Время
                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(recipe.timeText)
                            .font(.caption2)
                    }
                    
                    // Сложность
                    if !recipe.difficultyText.isEmpty {
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        Text(recipe.difficultyText)
                            .font(.caption2)
                    }
                    
                    // Калории
                    if let calories = recipe.calories, calories > 0 {
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 2) {
                            Image(systemName: "flame")
                                .font(.caption2)
                                .foregroundStyle(caloriesColor(calories))
                            Text("\(calories) ккал")
                                .font(.caption2)
                                .foregroundStyle(caloriesColor(calories))
                        }
                    }
                }
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .font(.caption2)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .opacity(0.7)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(
            color: .black.opacity(0.1),
            radius: 10,
            x: 0,
            y: 4
        )
    }
    
    private func caloriesColor(_ calories: Int) -> Color {
        switch calories {
        case 0..<200: return .green
        case 200..<400: return .orange
        default: return .red
        }
    }
}
