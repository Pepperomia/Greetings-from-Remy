import SwiftUI

struct SearchView: View {
    // MARK: - Enums
    
    private enum SearchMode: Sendable {
        case recipes
        case ingredients
        
        var title: String {
            switch self {
            case .recipes: return "Поиск по рецептам"
            case .ingredients: return "Поиск по ингредиентам"
            }
        }
    }
    
    // MARK: - Constants
    
    private enum Constants {
        static let mouseSize: CGFloat = 74
        static let plusSize: CGFloat = 58
        static let horizontalPadding: CGFloat = 12
        static let cardSpacing: CGFloat = 10
    }
    
    // MARK: - State
    
    @State private var query = ""
    @State private var results: [RecipeRow] = []
    @State private var errorText: String?
    
    // Режим поиска
    @State private var searchMode: SearchMode = .recipes
    
    // Ингредиенты
    @State private var selectedIngredients: [String] = []
    @State private var ingredientInput = ""
    @State private var showIngredientSuggestions = false
    @State private var availableIngredients: [String] = []
    
    // Фильтры
    @State private var categories: [CategoryRow] = []
    @State private var selectedCategoryId: Int? = nil
    
    @State private var cuisines: [CuisineRow] = []
    @State private var selectedCuisineId: Int? = nil
    
    @State private var filter30 = false
    @State private var showAddCuisine = false
    
    // Случайный рецепт
    @State private var surpriseRecipeId: Int? = nil
    
    // Кэши
    @State private var searchCache: [String: [RecipeRow]] = [:]
    @State private var cachedCategories: [CategoryRow] = []
    @State private var cachedCuisines: [CuisineRow] = []
    
    // UI состояние
    @State private var searchWorkItem: DispatchWorkItem?
    @State private var isSearching = false
    @State private var lastSearchTime = Date()
    
    private let searchDelay: TimeInterval = 0.5
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                
                content
            }
            .navigationTitle("Поиск")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Сброс", action: resetFilters)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("Режим", selection: $searchMode) {
                        Text("По рецептам").tag(SearchMode.recipes)
                        Text("По ингредиентам").tag(SearchMode.ingredients)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
            }
            .navigationDestination(isPresented: surpriseBinding) {
                if let id = surpriseRecipeId {
                    RecipeDetailView(recipeId: id, title: "Рецепт")
                }
            }
            .onAppear(perform: onAppear)
            .onChange(of: query) { _, _ in debounceSearch() }
            .onChange(of: selectedIngredients) { _, _ in debounceSearch() }
            .onChange(of: selectedCategoryId) { _, _ in debounceSearch() }
            .onChange(of: selectedCuisineId) { _, _ in debounceSearch() }
            .onChange(of: filter30) { _, _ in debounceSearch() }
            .onChange(of: searchMode) { _, _ in
                clearSearch()
                debounceSearch()
            }
        }
    }
    
    // MARK: - Content
    
    private var content: some View {
        ScrollView {
            VStack(spacing: Constants.cardSpacing) {
                // Показываем разные карточки в зависимости от режима
                if searchMode == .recipes {
                    recipesSearchCard
                } else {
                    ingredientsSearchCard
                }
                
                filtersCard
                resultsCard
            }
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.top, 8)
        }
    }
    
    // MARK: - Recipes Search Card
    
    private var recipesSearchCard: some View {
        VStack(alignment: .leading, spacing: Constants.cardSpacing) {
            Text("Поиск по рецептам")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 12)
            
            TextField("борщ, курица, сливки…", text: $query)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.regularMaterial)
                .cornerRadius(8)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .glassCard()
    }
    
    // MARK: - Ingredients Search Card
    
    private var ingredientsSearchCard: some View {
        VStack(alignment: .leading, spacing: Constants.cardSpacing) {
            Text("Поиск по ингредиентам")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 12)
            
            VStack(alignment: .leading, spacing: 12) {
                selectedIngredientsView
                ingredientInputView
                suggestionsView
            }
            .padding(.bottom, 12)
        }
        .glassCard()
    }
    
    private var selectedIngredientsView: some View {
        Group {
            if !selectedIngredients.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(selectedIngredients, id: \.self) { ingredient in
                            ingredientChip(ingredient)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
    }
    
    private func ingredientChip(_ ingredient: String) -> some View {
        HStack(spacing: 4) {
            Text(ingredient)
                .font(.subheadline)
            
            Button {
                selectedIngredients.removeAll { $0 == ingredient }
                debounceSearch()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial)
        .cornerRadius(16)
    }
    
    private var ingredientInputView: some View {
        HStack {
            TextField("Добавить ингредиент...", text: $ingredientInput)
                .textFieldStyle(.plain)
                .onSubmit(addIngredient)
                .onChange(of: ingredientInput) { _, newValue in
                    if !newValue.isEmpty {
                        showIngredientSuggestions = true
                        loadIngredientSuggestions(for: newValue)
                    } else {
                        showIngredientSuggestions = false
                    }
                }
            
            Button(action: addIngredient) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.mint)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .cornerRadius(8)
        .padding(.horizontal, 12)
    }
    
    private var suggestionsView: some View {
        Group {
            if showIngredientSuggestions && !availableIngredients.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(availableIngredients, id: \.self) { ingredient in
                            Button {
                                ingredientInput = ingredient
                                addIngredient()
                            } label: {
                                Text(ingredient)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.regularMaterial)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .padding(.bottom, 8)
            }
        }
    }
    
    // MARK: - Filters Card
    
    private var filtersCard: some View {
        VStack(alignment: .leading, spacing: Constants.cardSpacing) {
            Text("Фильтры")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 12)
            
            filtersRow
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .glassCard()
    }
    
    private var filtersRow: some View {
        HStack(spacing: 14) {
            watchButton
            surpriseButton
            categoryMenu
            cuisineMenu
            Spacer(minLength: 0)
        }
    }
    
    private var watchButton: some View {
        Button {
            filter30.toggle()
            debounceSearch()
        } label: {
            MouseSticker(name: "mouse_watch", size: Constants.mouseSize)
                .opacity(filter30 ? 1.0 : 0.55)
                .background(
                    Circle()
                        .fill(.regularMaterial)
                        .shadow(radius: 2)
                )
        }
        .buttonStyle(.plain)
    }
    
    private var surpriseButton: some View {
        Button(action: surpriseMe) {
            MouseSticker(name: "mouse_cube", size: Constants.mouseSize)
                .background(
                    Circle()
                        .fill(.regularMaterial)
                        .shadow(radius: 2)
                )
        }
        .buttonStyle(.plain)
    }
    
    private var categoryMenu: some View {
        Menu {
            Button("Все категории") {
                selectedCategoryId = nil
                debounceSearch()
            }
            Divider()
            ForEach(categories) { c in
                Button(c.name) {
                    selectedCategoryId = c.id
                    debounceSearch()
                }
            }
        } label: {
            MouseSticker(name: "mouse_book", size: Constants.mouseSize)
                .background(
                    Circle()
                        .fill(.regularMaterial)
                        .shadow(radius: 2)
                )
                .overlay(alignment: .bottomTrailing) { tinyChevron }
        }
        .buttonStyle(.plain)
    }
    
    private var cuisineMenu: some View {
        Menu {
            Button("Все кухни") {
                selectedCuisineId = nil
                debounceSearch()
            }
            Divider()
            ForEach(cuisines) { c in
                Button(c.name) {
                    selectedCuisineId = c.id
                    debounceSearch()
                }
            }
        } label: {
            MouseSticker(name: "mouse_world", size: Constants.mouseSize)
                .background(
                    Circle()
                        .fill(.regularMaterial)
                        .shadow(radius: 2)
                )
                .overlay(alignment: .bottomTrailing) { tinyChevron }
        }
        .buttonStyle(.plain)
    }
    
    private var tinyChevron: some View {
        Image(systemName: "chevron.down")
            .font(.caption2.weight(.semibold))
            .padding(6)
            .background(.regularMaterial)
            .clipShape(Circle())
            .offset(x: 6, y: 6)
    }
    
    // MARK: - Results Card
    
    private var resultsCard: some View {
        VStack(alignment: .leading, spacing: Constants.cardSpacing) {
            Text("Результаты (\(results.count))")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 12)
            
            if isSearching {
                loadingView
            } else if results.isEmpty {
                emptyView
            } else {
                resultsList
            }
            
            Spacer(minLength: 12)
        }
        .glassCard()
    }
    
    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 40)
            .padding(.horizontal, 12)
    }
    
    private var emptyView: some View {
        Text("Ничего не найдено")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 40)
            .padding(.horizontal, 12)
    }
    
    private var resultsList: some View {
        LazyVStack(spacing: 8) {
            ForEach(results) { recipe in
                NavigationLink {
                    RecipeDetailView(recipeId: recipe.id, title: recipe.title)
                } label: {
                    recipeRow(recipe)
                }
            }
        }
        .padding(.horizontal, 12)
    }
    
    private func recipeRow(_ recipe: RecipeRow) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                HStack(spacing: 10) {
                    Text("\(recipe.timeMinutes) мин")
                    Text(diffLabel(recipe.difficulty))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .cornerRadius(8)
    }
    
    // MARK: - Bindings
    
    private var surpriseBinding: Binding<Bool> {
        Binding(
            get: { surpriseRecipeId != nil },
            set: { if !$0 { surpriseRecipeId = nil } }
        )
    }
    
    // MARK: - Actions
    
    private func clearSearch() {
        query = ""
        selectedIngredients = []
        ingredientInput = ""
        results = []
    }
    
    private func debounceSearch() {
        print("⏱️ debounceSearch вызван")
        searchWorkItem?.cancel()
        
        let workItem = DispatchWorkItem {
            print("⏱️ запускаем runSearch")
            runSearch()
            lastSearchTime = Date()
        }
        searchWorkItem = workItem
        
        DispatchQueue.main.asyncAfter(deadline: .now() + searchDelay, execute: workItem)
    }
    
    private func addIngredient() {
        let trimmed = ingredientInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !selectedIngredients.contains(trimmed) else { return }
        
        selectedIngredients.append(trimmed)
        ingredientInput = ""
        showIngredientSuggestions = false
        debounceSearch()
    }
    
    private func loadIngredientSuggestions(for prefix: String) {
        do {
            availableIngredients = try DatabaseManager.shared.searchIngredientNames(prefix: prefix)
                .filter { !selectedIngredients.contains($0) }
                .prefix(5)
                .map { $0 }
        } catch {
            availableIngredients = []
        }
    }
    
    private func loadAllIngredients() {
        do {
            availableIngredients = try DatabaseManager.shared.getPopularIngredients(limit: 10)
        } catch {
            print("Ошибка загрузки ингредиентов: \(error)")
        }
    }
    
    private func resetFilters() {
        query = ""
        filter30 = false
        selectedCategoryId = nil
        selectedCuisineId = nil
        selectedIngredients = []
        ingredientInput = ""
        debounceSearch()
    }
    
    private func runSearch() {
        isSearching = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let cacheKey = "\(self.query)-\(self.selectedIngredients.joined(separator: ","))-\(self.selectedCategoryId.map(String.init) ?? "nil")-\(self.selectedCuisineId.map(String.init) ?? "nil")-\(self.filter30)-\(self.searchMode)"
            
            print("🔍 ===== ПОИСК =====")
            print("🔍 Режим: \(self.searchMode)")
            print("🔍 query: '\(self.query)'")
            print("🔍 ingredients: \(self.selectedIngredients)")
            
            if let cached = self.searchCache[cacheKey] {
                DispatchQueue.main.async {
                    print("✅ Из кэша: \(cached.count) рецептов")
                    self.results = cached
                    self.isSearching = false
                }
                return
            }
            
            do {
                let maxMin = self.filter30 ? 30 : nil
                
                let queryText = self.searchMode == .recipes ? self.query : ""
                let ingredientsList = self.searchMode == .ingredients ? self.selectedIngredients : nil
                
                print("🔍 Параметры запроса:")
                print("   queryText: '\(queryText)'")
                print("   ingredientsList: \(ingredientsList?.description ?? "nil")")
                
                let results = try DatabaseManager.shared.searchRecipes(
                    query: queryText,
                    ingredients: ingredientsList,
                    categoryId: self.selectedCategoryId,
                    cuisineId: self.selectedCuisineId,
                    maxMinutes: maxMin,
                    onlyEasy: false
                )
                
                print("✅ Найдено: \(results.count) рецептов")
                
                DispatchQueue.main.async {
                    self.results = results
                    self.searchCache[cacheKey] = results
                    self.isSearching = false
                }
            } catch {
                print("❌ Ошибка: \(error)")
                DispatchQueue.main.async {
                    self.errorText = "Ошибка поиска: \(error.localizedDescription)"
                    self.results = []
                    self.isSearching = false
                }
            }
        }
    }
    
    private func loadCategories() {
        guard cachedCategories.isEmpty else {
            categories = cachedCategories
            return
        }
        
        do {
            let fetched = try DatabaseManager.shared.fetchCategories()
            categories = fetched
            cachedCategories = fetched
        } catch {
            errorText = "Ошибка категорий: \(error.localizedDescription)"
        }
    }
    
    private func loadCuisines() {
        guard cachedCuisines.isEmpty else {
            cuisines = cachedCuisines
            return
        }
        
        do {
            let all = try DatabaseManager.shared.fetchAllCuisines()
            cuisines = all
            cachedCuisines = all
        } catch {
            errorText = "Ошибка кухонь: \(error.localizedDescription)"
        }
    }
    
    private func surpriseMe() {
        do {
            errorText = nil
            let maxMin = filter30 ? 30 : nil
            
            let queryText = searchMode == .recipes ? query : ""
            let ingredientsList = searchMode == .ingredients ? selectedIngredients : nil
            
            if let id = try DatabaseManager.shared.randomRecipeId(
                query: queryText,
                ingredients: ingredientsList,
                categoryId: selectedCategoryId,
                cuisineId: selectedCuisineId,
                maxMinutes: maxMin,
                onlyEasy: false
            ) {
                surpriseRecipeId = id
            } else {
                errorText = "Ничего не найдено 🙃"
            }
        } catch {
            errorText = error.localizedDescription
        }
    }
    
    private func onAppear() {
        loadCategories()
        loadCuisines()
        loadAllIngredients()
        
        do {
            let count = try DatabaseManager.shared.recipeCount()
            print("📊 Всего рецептов: \(count)")
        } catch {
            print("❌ Ошибка: \(error)")
        }
    }
    
    // MARK: - Helpers
    
    private func diffLabel(_ diff: String) -> String {
        switch diff {
        case "easy": return "легко"
        case "hard": return "сложно"
        default: return "средне"
        }
    }
}

// MARK: - Mouse Sticker

private struct MouseSticker: View {
    let name: String
    let size: CGFloat
    
    var body: some View {
        Image(name)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview {
    SearchView()
}
