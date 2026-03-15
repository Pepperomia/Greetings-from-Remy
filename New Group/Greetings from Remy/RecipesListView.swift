import SwiftUI

struct RecipesListView: View {
    
    // MARK: - Properties
    
    let category: CategoryRow
    
    // MARK: - State
    
    @State private var items: [RecipeRow] = []
    @State private var filteredItems: [RecipeRow] = []
    @State private var errorText: String?
    @FocusState private var isSearchFocused: Bool
    
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
    private let buttonSize: CGFloat = 70
    
    // MARK: - Computed Properties
    
    private var hasActiveFilters: Bool {
        filter30 || sortByCalories || selectedCuisineId != nil || !searchText.isEmpty
    }
    
    private var surpriseBinding: Binding<Bool> {
        Binding(
            get: { surpriseRecipeId != nil },
            set: { if !$0 { surpriseRecipeId = nil } }
        )
    }
    
    private var selectedCuisineName: String {
        guard let id = selectedCuisineId,
              let cuisine = cuisines.first(where: { $0.id == id }) else {
            return "Кухня"
        }
        return cuisine.name
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Стеклянная панель с поиском и фильтрами
                headerPanel
                    .padding(.top, 6)
                
                Divider()
                
                // Результаты
                resultsSection
            }
            .background(AppBackground(.list))
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
            .onTapGesture {
                isSearchFocused = false
            }
        }
        .onAppear {
            loadInitialData()
        }
        .onChange(of: filter30) { _, _ in applyFilters() }
        .onChange(of: sortByCalories) { _, _ in applyFilters() }
        .onChange(of: selectedCuisineId) { _, _ in applyFilters() }
        .onChange(of: searchText) { _, _ in applyFilters() }
    }
    
    // MARK: - Header Panel (стеклянная панель)
    
    private var headerPanel: some View {
        VStack(spacing: 16) {
            // Поисковая строка с кнопкой сброса
            HStack(spacing: 8) {
                // Поле поиска
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.headline)
                    
                    TextField("Поиск по названию...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .focused($isSearchFocused)
                        .submitLabel(.search)
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
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                
                // Кнопка сброса — всегда видна рядом с поиском
                Button {
                    resetFilters()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.caption.bold())
                        Text("Сброс")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Фильтры
            filtersRow
        }
        .padding(20)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 30)
                    .fill(.ultraThinMaterial)
                    .opacity(0.9)
                
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color.white.opacity(0.05))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(
            color: .black.opacity(0.15),
            radius: 20,
            y: 8
        )
        .padding(.horizontal, 16)
    }
    
    // MARK: - Results Section
    
    private var resultsSection: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                } else if let errorText {
                    errorView(errorText: errorText)
                        .padding(.top, 20)
                } else if filteredItems.isEmpty {
                    emptyView()
                        .padding(.top, 40)
                } else {
                    // Заголовок с результатами
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
                    .padding(.vertical, 8)
                    
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
                
                // Кнопка управления удалением (только если нет активных фильтров)
                if !hasActiveFilters {
                    deleteManagementButton
                        .padding(.top, 10)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
    }
    
    // MARK: - Filters Row
    
    private var filtersRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
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
            }
            .padding(.vertical, 8)
        }
    }
    
    private func filterButton(
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
        }
        .buttonStyle(BounceButtonStyle())
        .opacity(isActive ? 1.0 : 0.6)
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
        }
        .buttonStyle(BounceButtonStyle())
    }
    
    // MARK: - View Builders
    
    private func errorView(errorText: String) -> some View {
        Text(errorText)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
    }
    
    private func emptyView() -> some View {
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
    
    // MARK: - Delete Management
    
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
    
    private var deleteCategoryButton: some View {
        Button {
            showingDeleteAlert = true
        } label: {
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
    
    // MARK: - Data Loading
    
    private func loadInitialData() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            loadCuisinesSync()
            loadRecipesSync()
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
    
    // MARK: - Filtering
    
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
    
    private func surpriseMe() {
        guard !filteredItems.isEmpty else { return }
        surpriseRecipeId = filteredItems.randomElement()?.id
    }
    
    private func resetFilters() {
        searchText = ""
        filter30 = false
        sortByCalories = false
        selectedCuisineId = nil
        applyFilters()
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

// MARK: - Recipe Card Row

private struct RecipeCardRow: View {
    let recipe: RecipeRow
    
    private func caloriesColor(_ calories: Int) -> Color {
        switch calories {
        case 0..<200: return .green
        case 200..<400: return .orange
        default: return .red
        }
    }
    
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
}
