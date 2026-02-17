import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var results: [RecipeRow] = []
    @State private var errorText: String?
    
    // Для множественного выбора ингредиентов
    @State private var selectedIngredients: [String] = []
    @State private var ingredientInput = ""
    @State private var showIngredientSuggestions = false
    @State private var availableIngredients: [String] = []

    @State private var categories: [CategoryRow] = []
    @State private var selectedCategoryId: Int? = nil

    @State private var cuisines: [CuisineRow] = []
    @State private var selectedCuisineId: Int? = nil

    @State private var surpriseRecipeId: Int? = nil

    @State private var filter30 = false
    @State private var showAddCuisine = false

    // MARK: - UI

    private enum UI {
        static let mouseSize: CGFloat = 64
        static let plusSize: CGFloat = 38
        static let topPad: CGFloat = 12
        static let sidePad: CGFloat = 16
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        
                        // Поисковая строка в стеклянной карточке
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Поиск")
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
                        
                        // Множественный выбор ингредиентов
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ингредиенты")
                                .font(.headline)
                                .padding(.horizontal, 12)
                                .padding(.top, 12)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                // Выбранные ингредиенты
                                if !selectedIngredients.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack {
                                            ForEach(selectedIngredients, id: \.self) { ingredient in
                                                HStack(spacing: 4) {
                                                    Text(ingredient)
                                                        .font(.subheadline)
                                                    
                                                    Button {
                                                        selectedIngredients.removeAll { $0 == ingredient }
                                                        runSearch()
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
                                        }
                                        .padding(.horizontal, 12)
                                    }
                                }
                                
                                // Поле ввода ингредиента
                                HStack {
                                    TextField("Добавить ингредиент...", text: $ingredientInput)
                                        .textFieldStyle(.plain)
                                        .onSubmit {
                                            addIngredient()
                                        }
                                        .onChange(of: ingredientInput) { _, newValue in
                                            if !newValue.isEmpty {
                                                showIngredientSuggestions = true
                                                loadIngredientSuggestions(for: newValue)
                                            } else {
                                                showIngredientSuggestions = false
                                            }
                                        }
                                    
                                    Button {
                                        addIngredient()
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(.mint)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.regularMaterial)
                                .cornerRadius(8)
                                .padding(.horizontal, 12)
                                
                                // Подсказки ингредиентов
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
                            .padding(.bottom, 12)
                        }
                        .glassCard()

                        // Мышиные фильтры
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Фильтры")
                                .font(.headline)
                                .padding(.horizontal, 12)
                                .padding(.top, 12)
                            
                            filtersRow
                                .padding(.horizontal, 12)
                                .padding(.bottom, 12)
                        }
                        .glassCard()

                        // Результаты
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Результаты (\(results.count))")
                                .font(.headline)
                                .padding(.horizontal, 12)
                                .padding(.top, 12)
                            
                            if results.isEmpty {
                                Text("Ничего не найдено")
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 40)
                                    .padding(.horizontal, 12)
                            } else {
                                LazyVStack(spacing: 8) {
                                    ForEach(results) { r in
                                        NavigationLink {
                                            RecipeDetailView(recipeId: r.id, title: r.title)
                                        } label: {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(r.title)
                                                        .font(.body)
                                                        .foregroundColor(.primary)
                                                    
                                                    HStack(spacing: 10) {
                                                        Text("\(r.timeMinutes) мин")
                                                        Text(diffLabel(r.difficulty))
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
                                    }
                                }
                                .padding(.horizontal, 12)
                            }
                            
                            Spacer(minLength: 12)
                        }
                        .glassCard()
                    }
                    .padding()
                }
            }
            .navigationTitle("Поиск")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Сброс") { resetFilters() }
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { surpriseRecipeId != nil },
                set: { if !$0 { surpriseRecipeId = nil } }
            )) {
                RecipeDetailView(recipeId: surpriseRecipeId ?? 0, title: "Рецепт")
            }
            .onAppear {
                loadCategories()
                loadCuisines()
                loadAllIngredients()
                runSearch()
            }
            .onChange(of: query) { _, _ in runSearch() }
            .onChange(of: filter30) { _, _ in runSearch() }
            .onChange(of: selectedCategoryId) { _, _ in runSearch() }
            .onChange(of: selectedCuisineId) { _, _ in runSearch() }
            .sheet(isPresented: $showAddCuisine) {
                AddCuisineSheet { loadCuisines() }
            }
        }
    }

    // MARK: - Filters row (мыши)

    private var filtersRow: some View {
        HStack(spacing: 14) {

            // 1) watch
            Button {
                filter30.toggle()
            } label: {
                MouseSticker("mouse_watch", size: UI.mouseSize)
                    .opacity(filter30 ? 1.0 : 0.55)
                    .background(
                        Circle()
                            .fill(.regularMaterial)
                            .shadow(radius: 2)
                    )
            }
            .buttonStyle(.plain)

            // 2) cube
            Button {
                surpriseMe()
            } label: {
                MouseSticker("mouse_cube", size: UI.mouseSize)
                    .background(
                        Circle()
                            .fill(.regularMaterial)
                            .shadow(radius: 2)
                    )
            }
            .buttonStyle(.plain)

            // 3) book (категории)
            Menu {
                Button("Все категории") { selectedCategoryId = nil }
                Divider()
                ForEach(categories) { c in
                    Button(c.name) { selectedCategoryId = c.id }
                }
            } label: {
                MouseSticker("mouse_book", size: UI.mouseSize)
                    .background(
                        Circle()
                            .fill(.regularMaterial)
                            .shadow(radius: 2)
                    )
                    .overlay(alignment: .bottomTrailing) { tinyChevron }
            }
            .buttonStyle(.plain)

            // 4) world (кухни)
            Menu {
                Button("Все кухни") { selectedCuisineId = nil }
                Divider()
                ForEach(cuisines) { c in
                    Button(c.name) { selectedCuisineId = c.id }
                }
            } label: {
                MouseSticker("mouse_world", size: UI.mouseSize)
                    .background(
                        Circle()
                            .fill(.regularMaterial)
                            .shadow(radius: 2)
                    )
                    .overlay(alignment: .bottomTrailing) { tinyChevron }
            }
            .buttonStyle(.plain)

            // 5) плюс рядом с world
            Button {
                showAddCuisine = true
            } label: {
                Image(systemName: "plus")
                    .font(.headline)
                    .frame(width: UI.plusSize, height: UI.plusSize)
                    .background(.regularMaterial)
                    .clipShape(Circle())
                    .shadow(radius: 2)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
    }

    private var tinyChevron: some View {
        Image(systemName: "chevron.down")
            .font(.caption2.weight(.semibold))
            .padding(6)
            .background(.regularMaterial)
            .clipShape(Circle())
            .offset(x: 6, y: 6)
    }

    // MARK: - Ingredient Management

    private func addIngredient() {
        let trimmed = ingredientInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !selectedIngredients.contains(trimmed) {
            selectedIngredients.append(trimmed)
            ingredientInput = ""
            showIngredientSuggestions = false
            runSearch()
        }
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
            // Загружаем популярные ингредиенты для подсказок
            availableIngredients = try DatabaseManager.shared.getPopularIngredients(limit: 10)
        } catch {
            print("Ошибка загрузки ингредиентов: \(error)")
        }
    }

    // MARK: - Data

    private func resetFilters() {
        query = ""
        filter30 = false
        selectedCategoryId = nil
        selectedCuisineId = nil
        selectedIngredients = []
        ingredientInput = ""
        runSearch()
    }

    private func runSearch() {
        do {
            errorText = nil
            let maxMin = filter30 ? 30 : nil

            results = try DatabaseManager.shared.searchRecipes(
                query: query,
                ingredients: selectedIngredients.isEmpty ? nil : selectedIngredients,
                categoryId: selectedCategoryId,
                cuisineId: selectedCuisineId,
                maxMinutes: maxMin,
                onlyEasy: false
            )
        } catch {
            errorText = "Ошибка поиска: \(error.localizedDescription)"
            results = []
        }
    }

    private func loadCategories() {
        do {
            categories = try DatabaseManager.shared.fetchCategories()
        } catch {
            errorText = "Ошибка категорий: \(error.localizedDescription)"
        }
    }

    private func loadCuisines() {
        do {
            let all = try DatabaseManager.shared.fetchAllCuisines()
            cuisines = all.filter { $0.name.first.map(isUppercaseFirstLetter) ?? true }
        } catch {
            errorText = "Ошибка кухонь: \(error.localizedDescription)"
        }
    }

    private func isUppercaseFirstLetter(_ ch: Character) -> Bool {
        if let scalar = ch.unicodeScalars.first {
            return !CharacterSet.lowercaseLetters.contains(scalar)
        }
        return true
    }

    private func surpriseMe() {
        do {
            errorText = nil
            let maxMin = filter30 ? 30 : nil

            if let id = try DatabaseManager.shared.randomRecipeId(
                query: query,
                ingredients: selectedIngredients.isEmpty ? nil : selectedIngredients,
                categoryId: selectedCategoryId,
                cuisineId: selectedCuisineId,
                maxMinutes: maxMin,
                onlyEasy: false
            ) {
                surpriseRecipeId = id
            } else {
                errorText = "Ничего не найдено под эти фильтры 🙃"
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func diffLabel(_ diff: String) -> String {
        switch diff {
        case "easy": return "легко"
        case "hard": return "сложно"
        default: return "средне"
        }
    }

    // MARK: - Mouse helper

    private struct MouseSticker: View {
        let name: String
        let size: CGFloat

        init(_ name: String, size: CGFloat = 52) {
            self.name = name
            self.size = size
        }

        var body: some View {
            Image(name)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .accessibilityHidden(true)
        }
    }
}
