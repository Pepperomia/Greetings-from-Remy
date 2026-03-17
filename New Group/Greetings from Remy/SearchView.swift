import SwiftUI

struct SearchView: View {
    
    // MARK: - States
    
    @State private var query: String = ""
    @State private var results: [RecipeRow] = []
    @State private var isSearching = false
    @State private var errorText: String?
    @FocusState private var isSearchFocused: Bool
    
    // MARK: - Фильтры
    @State private var filter30 = false
    @State private var sortByCalories = false
    @State private var originalResults: [RecipeRow] = []
    
    // MARK: - Фильтр по кухням
    @State private var cuisines: [CuisineRow] = []
    @State private var selectedCuisineId: Int?
    
    // MARK: - Поиск по ингредиентам
    @State private var searchMode: SearchMode = .name
    @State private var selectedIngredients: [String] = []
    @State private var ingredientInput = ""
    @State private var ingredientSuggestions: [String] = []
    @State private var showSuggestions = false
    @State private var popularIngredients: [String] = []
    
    // MARK: - Сюрприз
    @State private var surpriseRecipeId: Int?
    
    // MARK: - Кэширование
    @State private var searchCache: [String: [RecipeRow]] = [:]
    private let minimumSearchLength = 2
    
    enum SearchMode: String, CaseIterable {
        case name = "По названию"
        case ingredients = "По ингредиентам"
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Стеклянная панель с поиском и фильтрами
                headerPanel
                    .padding(.top, 6)
                
                Divider()
                    .padding(.top, 4)
                
                // Результаты
                if isSearching {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                } else if let errorText {
                    errorView(errorText: errorText)
                        .padding(.top, 20)
                } else if results.isEmpty && hasSearchQuery {
                    emptyView
                        .padding(.top, 40)
                } else if !results.isEmpty {
                    resultsSection
                } else {
                    // Пустое состояние при первом запуске
                    emptyInitialView
                        .padding(.top, 40)
                }
                
                Spacer()
            }
            .background(AppBackground())
            .navigationTitle("Поиск")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: surpriseBinding) {
                if let id = surpriseRecipeId {
                    RecipeDetailView(recipeId: id)
                }
            }
            .onTapGesture {
                isSearchFocused = false
            }
            .onAppear {
                loadInitialData()
            }
        }
        .onChange(of: filter30) { _, _ in
            applyFilters()
        }
        .onChange(of: sortByCalories) { _, newValue in
            if newValue {
                sortResultsByCalories()
            } else {
                results = originalResults
            }
        }
        .onChange(of: selectedCuisineId) { _, _ in
            applyFilters()
        }
    }
    
    // MARK: - Header Panel (стеклянная панель)
    
    private var headerPanel: some View {
        VStack(spacing: 16) {
            // Поисковая строка с кнопкой сброса
            HStack(spacing: 8) {
                if searchMode == .name {
                    // Поиск по названию
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.headline)
                        
                        TextField("борщ, курица, сливки…", text: $query)
                            .textFieldStyle(.plain)
                            .font(.body)
                            .focused($isSearchFocused)
                            .submitLabel(.search)
                            .onSubmit {
                                runSearch()
                            }
                        
                        if !query.isEmpty {
                            Button {
                                query = ""
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
                } else {
                    // Поиск по ингредиентам
                    HStack {
                        Image(systemName: "carrot")
                            .foregroundStyle(.secondary)
                            .font(.headline)
                        
                        TextField("Добавить ингредиент...", text: $ingredientInput)
                            .textFieldStyle(.plain)
                            .font(.body)
                            .focused($isSearchFocused)
                            .onSubmit {
                                addIngredient()
                            }
                        
                        Button {
                            addIngredient()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.mint)
                                .font(.title2)
                        }
                        .disabled(ingredientInput.isEmpty)
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
                }
                
                // Кнопка сброса (только если есть активные фильтры или поиск)
                if hasActiveFilters {
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
            }
            
            // Mode Picker
            Picker("Режим поиска", selection: $searchMode) {
                ForEach(SearchMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: searchMode) { _, _ in
                clearSearch()
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
    
    // MARK: - Computed Properties
    
    private var hasSearchQuery: Bool {
        if searchMode == .name {
            return !query.isEmpty
        } else {
            return !selectedIngredients.isEmpty
        }
    }
    
    private var hasActiveFilters: Bool {
        filter30 || sortByCalories || selectedCuisineId != nil || !query.isEmpty || !selectedIngredients.isEmpty
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
            return "Все кухни"
        }
        return cuisine.name
    }
    
    // MARK: - Empty Views
    
    private var emptyInitialView: some View {
        VStack(spacing: 16) {
            Image(systemName: searchMode == .name ? "magnifyingglass" : "carrot")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            
            Text(searchMode == .name ? "Введите название рецепта" : "Добавьте ингредиенты")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Load Initial Data
    
    private func loadInitialData() {
        DispatchQueue.global(qos: .utility).async { [self] in
            self.loadPopularIngredientsSync()
            self.loadCuisinesSync()
        }
    }
    
    private func loadPopularIngredientsSync() {
        do {
            let popular = try DatabaseManager.shared.getPopularIngredients(limit: 15)
            DispatchQueue.main.async {
                self.popularIngredients = popular
            }
        } catch {
            print("Ошибка загрузки популярных ингредиентов: \(error)")
        }
    }
    
    private func loadCuisinesSync() {
        do {
            let fetched = try DatabaseManager.shared.fetchAllCuisines()
            DispatchQueue.main.async {
                self.cuisines = fetched
                print("✅ Загружено кухонь: \(fetched.count)") // Для отладки
                for cuisine in fetched {
                    print("   - \(cuisine.name)")
                }
            }
        } catch {
            print("❌ Ошибка загрузки кухонь: \(error)")
        }
    }
    
    // MARK: - Ingredients Content
    
    @ViewBuilder
    private var ingredientsContent: some View {
        if searchMode == .ingredients {
            VStack(alignment: .leading, spacing: 16) {
                // Выбранные ингредиенты
                if !selectedIngredients.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(selectedIngredients, id: \.self) { ingredient in
                                ingredientChip(ingredient)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .padding(.horizontal, 16)
                }
                
                // Подсказки
                if showSuggestions && !ingredientSuggestions.isEmpty {
                    suggestionsScrollView
                        .padding(.horizontal, 16)
                }
                
                // Популярные ингредиенты
                if ingredientInput.isEmpty && !popularIngredients.isEmpty && selectedIngredients.isEmpty {
                    popularIngredientsView
                        .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private func ingredientChip(_ ingredient: String) -> some View {
        HStack(spacing: 6) {
            Text(ingredient)
                .font(.subheadline)
            
            Button {
                selectedIngredients.removeAll { $0 == ingredient }
                if !selectedIngredients.isEmpty {
                    runSearch()
                } else {
                    results = []
                    originalResults = []
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.regularMaterial)
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var suggestionsScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ingredientSuggestions, id: \.self) { suggestion in
                    Button {
                        ingredientInput = suggestion
                        addIngredient()
                    } label: {
                        Text(suggestion)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    private var popularIngredientsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Популярные ингредиенты")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(popularIngredients, id: \.self) { ingredient in
                        Button {
                            ingredientInput = ingredient
                            addIngredient()
                        } label: {
                            Text(ingredient)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private func addIngredient() {
        let trimmed = ingredientInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !selectedIngredients.contains(trimmed) else { return }
        
        selectedIngredients.append(trimmed)
        ingredientInput = ""
        showSuggestions = false
        runSearch()
    }
    
    private func loadIngredientSuggestions(for prefix: String) {
        guard prefix.count >= 1 else { return }
        
        DispatchQueue.global(qos: .utility).async { [self] in
            do {
                let suggestions = try DatabaseManager.shared.searchIngredientSuggestions(prefix: prefix)
                DispatchQueue.main.async {
                    self.ingredientSuggestions = suggestions
                }
            } catch {
                print("Ошибка загрузки подсказок: \(error)")
                DispatchQueue.main.async {
                    self.ingredientSuggestions = []
                }
            }
        }
    }
    
    // MARK: - Filters
    
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
                    .frame(width: 70, height: 70)
                
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
                        .frame(width: 70, height: 70)
                    
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
    
    private func surpriseMe() {
        guard !results.isEmpty else { return }
        surpriseRecipeId = results.randomElement()?.id
    }
    
    // MARK: - Results Section
    
    private var resultsSection: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                // Заголовок с результатами
                HStack {
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text("Результаты")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("\(results.count) \(recipeWord(for: results.count))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
                
                // Дополнительный контент для ингредиентов
                if searchMode == .ingredients {
                    ingredientsContent
                }
                
                // Карточки рецептов
                LazyVStack(spacing: 12) {
                    ForEach(results) { recipe in
                        NavigationLink {
                            RecipeDetailView(recipeId: recipe.id)
                        } label: {
                            ImprovedRecipeCardRow(recipe: recipe)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
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
    
    // MARK: - Empty View & Error View
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: searchMode == .name ? "magnifyingglass" : "carrot")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            
            Text(searchMode == .name ? "Ничего не найдено" : "Нет рецептов с такими ингредиентами")
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func errorView(errorText: String) -> some View {
        Text(errorText)
            .foregroundStyle(.red)
            .font(.caption)
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
    }
    
    // MARK: - Search Logic

    private func clearSearch() {
        query = ""
        selectedIngredients = []
        ingredientInput = ""
        results = []
        originalResults = []
        filter30 = false
        sortByCalories = false
        selectedCuisineId = nil
        showSuggestions = false
        searchCache.removeAll()
    }

    private func runSearch() {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if searchMode == .name {
            guard trimmedQuery.count >= minimumSearchLength else {
                results = []
                originalResults = []
                return
            }
        } else {
            guard !selectedIngredients.isEmpty else {
                results = []
                originalResults = []
                return
            }
        }
        
        let cacheKey = "\(searchMode)-\(trimmedQuery)-\(selectedIngredients.joined(separator: ","))-\(selectedCuisineId ?? 0)-\(filter30)-\(sortByCalories)"
        
        if let cached = searchCache[cacheKey] {
            results = cached
            originalResults = cached
            applyFilters()
            return
        }
        
        isSearching = true
        errorText = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            do {
                let found: [RecipeRow]
                
                if searchMode == .name {
                    found = try DatabaseManager.shared.searchRecipes(
                        query: trimmedQuery,
                        cuisineId: selectedCuisineId
                    )
                } else {
                    found = try DatabaseManager.shared.searchRecipesByIngredients(
                        selectedIngredients,
                        cuisineId: selectedCuisineId
                    )
                }
                
                DispatchQueue.main.async {
                    self.searchCache[cacheKey] = found
                    self.originalResults = found
                    self.applyFilters()
                    self.isSearching = false
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.errorText = error.localizedDescription
                    self.isSearching = false
                }
            }
        }
    }
    
    private func applyFilters() {
        guard !originalResults.isEmpty else { return }
        
        var filtered = originalResults
        
        // Фильтр по времени
        if filter30 {
            filtered = filtered.filter { $0.timeMinutes <= 30 }
        }
        
        results = filtered
        
        if sortByCalories {
            sortResultsByCalories()
        }
    }
    
    private func sortResultsByCalories() {
        results.sort { recipe1, recipe2 in
            let calories1 = recipe1.calories ?? 0
            let calories2 = recipe2.calories ?? 0
            return calories1 < calories2
        }
    }
    
    private func resetFilters() {
        query = ""
        ingredientInput = ""
        selectedIngredients = []
        filter30 = false
        sortByCalories = false
        selectedCuisineId = nil
        showSuggestions = false
        results = []
        originalResults = []
        isSearchFocused = false
    }
}

// MARK: - Улучшенная карточка рецепта с калориями

private struct ImprovedRecipeCardRow: View {
    let recipe: RecipeRow
    
    private var caloriesColor: Color {
        guard let calories = recipe.calories else { return .secondary }
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
                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(recipe.timeText)
                            .font(.caption2)
                    }
                    
                    if let calories = recipe.calories, calories > 0 {
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 2) {
                            Image(systemName: "flame")
                                .font(.caption2)
                                .foregroundStyle(caloriesColor)
                            Text("\(calories) ккал")
                                .font(.caption2)
                                .foregroundStyle(caloriesColor)
                        }
                    }
                    
                    if !recipe.difficultyText.isEmpty {
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        Text(recipe.difficultyText)
                            .font(.caption2)
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
