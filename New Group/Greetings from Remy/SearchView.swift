import SwiftUI

struct SearchView: View {
    
    // MARK: - States
    
    @State private var query: String = ""
    @State private var results: [RecipeRow] = []
    @State private var isSearching = false
    @State private var errorText: String?
    
    // MARK: - Фильтры
    @State private var filter30 = false
    @State private var sortByCalories = false
    @State private var originalResults: [RecipeRow] = []
    
    // MARK: - Поиск по ингредиентам
    @State private var searchMode: SearchMode = .name
    @State private var selectedIngredients: [String] = []
    @State private var ingredientInput = ""
    @State private var ingredientSuggestions: [String] = []
    @State private var showSuggestions = false
    @State private var popularIngredients: [String] = []
    
    // MARK: - Сюрприз
    @State private var surpriseRecipeId: Int?
    
    enum SearchMode: String, CaseIterable {
        case name = "По названию"
        case ingredients = "По ингредиентам"
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            AppBackground()
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Search Card
                    VStack(spacing: 16) {
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
                        
                        // Search Field
                        if searchMode == .name {
                            TextField("борщ, курица, сливки…", text: $query)
                                .textFieldStyle(.plain)
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
                                .onSubmit {
                                    runSearch()
                                }
                        } else {
                            ingredientsSearchField
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.regularMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
                    
                    // Filters Row
                    filtersRow
                    
                    // Results
                    if isSearching {
                        ProgressView()
                            .padding(.top, 40)
                    } else if let errorText {
                        errorView(errorText: errorText)
                    } else if results.isEmpty && hasSearchQuery {
                        emptyView
                    } else if !results.isEmpty {
                        resultsSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Поиск")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: surpriseBinding) {
            if let id = surpriseRecipeId {
                RecipeDetailView(recipeId: id)
            }
        }
        .onAppear {
            loadPopularIngredients()
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
    }
    
    // MARK: - Computed Properties
    
    private var hasSearchQuery: Bool {
        if searchMode == .name {
            return !query.isEmpty
        } else {
            return !selectedIngredients.isEmpty
        }
    }
    
    private var surpriseBinding: Binding<Bool> {
        Binding(
            get: { surpriseRecipeId != nil },
            set: { if !$0 { surpriseRecipeId = nil } }
        )
    }
}

// MARK: - Ingredients Search Field

private extension SearchView {
    
    var ingredientsSearchField: some View {
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
            }
            
            // Поле ввода
            HStack {
                TextField("Добавить ингредиент...", text: $ingredientInput)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        addIngredient()
                    }
                    .onChange(of: ingredientInput) { _, newValue in
                        if !newValue.isEmpty {
                            loadIngredientSuggestions(for: newValue)
                            showSuggestions = true
                        } else {
                            showSuggestions = false
                        }
                    }
                
                Button(action: addIngredient) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.mint)
                }
                .disabled(ingredientInput.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            
            // Подсказки
            if showSuggestions && !ingredientSuggestions.isEmpty {
                suggestionsScrollView
            }
            
            // Популярные ингредиенты
            if ingredientInput.isEmpty && !popularIngredients.isEmpty && selectedIngredients.isEmpty {
                popularIngredientsView
            }
        }
    }
    
    func ingredientChip(_ ingredient: String) -> some View {
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
    
    var suggestionsScrollView: some View {
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
    
    var popularIngredientsView: some View {
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
    
    func addIngredient() {
        let trimmed = ingredientInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !selectedIngredients.contains(trimmed) else { return }
        
        selectedIngredients.append(trimmed)
        ingredientInput = ""
        showSuggestions = false
        runSearch()
    }
    
    func loadIngredientSuggestions(for prefix: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let suggestions = try DatabaseManager.shared.searchIngredientSuggestions(prefix: prefix)
                DispatchQueue.main.async {
                    ingredientSuggestions = suggestions
                }
            } catch {
                print("Ошибка загрузки подсказок: \(error)")
                ingredientSuggestions = []
            }
        }
    }
    
    func loadPopularIngredients() {
        DispatchQueue.global(qos: .background).async {
            do {
                let popular = try DatabaseManager.shared.getPopularIngredients(limit: 15)
                DispatchQueue.main.async {
                    popularIngredients = popular
                }
            } catch {
                print("Ошибка загрузки популярных ингредиентов: \(error)")
            }
        }
    }
}

// MARK: - Filters

private extension SearchView {
    
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
    
    func surpriseMe() {
        guard !results.isEmpty else { return }
        surpriseRecipeId = results.randomElement()?.id
    }
}

// MARK: - Results Section

private extension SearchView {
    
    var resultsSection: some View {
        VStack(spacing: 16) {
            // Заголовок по центру
            HStack {
                Spacer()
                
                VStack(spacing: 4) {
                    Text("Результаты")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("\(results.count) \(recipeWord(for: results.count))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
            
            // Карточки рецептов
            LazyVStack(spacing: 16) {
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
    }
    
    // Вспомогательная функция для склонения слова "рецепт"
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

// MARK: - Улучшенная карточка рецепта с калориями

private struct ImprovedRecipeCardRow: View {
    let recipe: RecipeRow
    
    // Цвет для калорий в зависимости от значения
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
                    
                    // Калории - показываем реальные данные
                    if let calories = recipe.calories, calories > 0 {
                        Text("•")
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "flame")
                                .font(.caption2)
                                .foregroundStyle(caloriesColor)
                            Text("\(calories) ккал")
                                .font(.caption)
                                .foregroundStyle(caloriesColor)
                        }
                    } else if let calories = recipe.calories, calories == 0 {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text("0 ккал")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    // Если calories = nil, просто не показываем калории
                    
                    // Сложность
                    if !recipe.difficultyText.isEmpty {
                        Text("•")
                            .foregroundStyle(.secondary)
                        
                        Text(recipe.difficultyText)
                            .font(.caption)
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
}

// MARK: - Empty View & Error View

private extension SearchView {
    
    var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: searchMode == .name ? "magnifyingglass" : "carrot")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            
            Text(searchMode == .name ? "Ничего не найдено" : "Нет рецептов с такими ингредиентами")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }
    
    func errorView(errorText: String) -> some View {
        Text(errorText)
            .foregroundStyle(.red)
            .padding(.top, 40)
    }
}

// MARK: - Search Logic

private extension SearchView {
    
    func clearSearch() {
        query = ""
        selectedIngredients = []
        ingredientInput = ""
        results = []
        originalResults = []
        filter30 = false
        sortByCalories = false
        showSuggestions = false
    }
    
    func runSearch() {
        if searchMode == .name {
            let text = query.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else {
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
        
        isSearching = true
        errorText = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let found: [RecipeRow]
                
                if searchMode == .name {
                    found = try DatabaseManager.shared.searchRecipes(query: query)
                } else {
                    found = try DatabaseManager.shared.searchRecipesByIngredients(selectedIngredients)
                }
                
                DispatchQueue.main.async {
                    // НЕ генерируем случайные калории, используем реальные
                    self.originalResults = found
                    
                    // Отладка - посмотрим реальные калории
                    for recipe in found {
                        print("🔍 Рецепт: \(recipe.title), калории из БД: \(recipe.calories?.description ?? "nil")")
                    }
                    
                    var filtered = found
                    if self.filter30 {
                        filtered = filtered.filter { $0.timeMinutes <= 30 }
                    }
                    
                    self.results = filtered
                    self.isSearching = false
                    
                    if self.sortByCalories {
                        self.sortResultsByCalories()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorText = error.localizedDescription
                    self.isSearching = false
                }
            }
        }
    }
    
    func applyFilters() {
        guard !originalResults.isEmpty else { return }
        
        var filtered = originalResults
        
        if filter30 {
            filtered = filtered.filter { $0.timeMinutes <= 30 }
        }
        
        results = filtered
        
        if sortByCalories {
            sortResultsByCalories()
        }
    }
    
    func sortResultsByCalories() {
        results.sort { recipe1, recipe2 in
            let calories1 = recipe1.calories ?? 0
            let calories2 = recipe2.calories ?? 0
            return calories1 < calories2
        }
    }
}
