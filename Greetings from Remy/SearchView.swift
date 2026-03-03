import SwiftUI

struct SearchView: View {

    private enum SearchMode {
        case recipes
        case ingredients
    }

    // MARK: - State

    @State private var searchMode: SearchMode = .recipes

    @State private var query = ""
    @State private var selectedIngredients: [String] = []
    @State private var ingredientInput = ""

    @State private var results: [RecipeRow] = []
    @State private var errorText: String?
    @State private var isSearching = false

    @State private var categories: [CategoryRow] = []
    @State private var selectedCategoryId: Int? = nil

    @State private var cuisines: [CuisineRow] = []
    @State private var selectedCuisineId: Int? = nil

    @State private var filter30 = false
    @State private var surpriseRecipeId: Int? = nil

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        modePicker
                        searchCard
                        filtersCard
                        resultsCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
            }
            .navigationTitle("Поиск")
            .navigationDestination(isPresented: surpriseBinding) {
                if let id = surpriseRecipeId {
                    RecipeDetailView(recipeId: id)
                }
            }
            .onAppear {
                loadCategories()
                loadCuisines()
            }
            .onChange(of: query) { _, _ in runSearch() }
            .onChange(of: selectedIngredients) { _, _ in runSearch() }
            .onChange(of: selectedCategoryId) { _, _ in runSearch() }
            .onChange(of: selectedCuisineId) { _, _ in runSearch() }
            .onChange(of: filter30) { _, _ in runSearch() }
        }
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        Picker("Режим", selection: $searchMode) {
            Text("📖 Рецепты").tag(SearchMode.recipes)
            Text("🥕 Ингредиенты").tag(SearchMode.ingredients)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Search Card

    private var searchCard: some View {
        VStack(spacing: 10) {

            if searchMode == .recipes {

                TextField("Название рецепта…", text: $query)
                    .textFieldStyle(.roundedBorder)

            } else {

                VStack(spacing: 8) {

                    TextField("Добавить ингредиент…", text: $ingredientInput)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addIngredient)

                    if !selectedIngredients.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(selectedIngredients, id: \.self) { item in
                                    ingredientChip(item)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .glassCard()
    }

    private func ingredientChip(_ name: String) -> some View {
        HStack {
            Text(name).font(.caption)

            Button {
                selectedIngredients.removeAll { $0 == name }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(6)
        .background(.regularMaterial)
        .cornerRadius(12)
    }

    private func addIngredient() {
        let trimmed = ingredientInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !selectedIngredients.contains(trimmed) else { return }

        selectedIngredients.append(trimmed)
        ingredientInput = ""
    }

    // MARK: - Filters

    private var filtersCard: some View {
        VStack(spacing: 12) {

            Toggle("До 30 минут", isOn: $filter30)

            categoryMenu
            cuisineMenu

            Button("🎲 Сюрприз") {
                surpriseMe()
            }
        }
        .padding()
        .glassCard()
    }

    private var categoryMenu: some View {
        Menu {
            Button("Все категории") { selectedCategoryId = nil }

            ForEach(categories) { c in
                Button(c.name) { selectedCategoryId = c.id }
            }
        } label: {
            labelRow("Категория", selectedCategoryName)
        }
    }

    private var cuisineMenu: some View {
        Menu {
            Button("Все кухни") { selectedCuisineId = nil }

            ForEach(cuisines) { c in
                Button(c.name) { selectedCuisineId = c.id }
            }
        } label: {
            labelRow("Кухня", selectedCuisineName)
        }
    }

    private func labelRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.regularMaterial)
        .cornerRadius(8)
    }

    private var selectedCategoryName: String {
        categories.first(where: { $0.id == selectedCategoryId })?.name ?? "Все"
    }

    private var selectedCuisineName: String {
        cuisines.first(where: { $0.id == selectedCuisineId })?.name ?? "Все"
    }

    // MARK: - Results

    private var resultsCard: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("Результаты (\(results.count))")
                .font(.headline)

            if isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if results.isEmpty {
                Text("Ничего не найдено")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(results) { recipe in
                    NavigationLink {
                        RecipeDetailView(recipeId: recipe.id)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(recipe.title)
                            Text(recipe.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(.regularMaterial)
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .glassCard()
    }

    // MARK: - Search Logic

    private func runSearch() {

        isSearching = true

        DispatchQueue.global(qos: .userInitiated).async {

            do {
                let maxMinutes = filter30 ? 30 : nil

                let searchText = searchMode == .recipes ? query : ""
                let ingredientsList = searchMode == .ingredients ? selectedIngredients : nil

                let found = try DatabaseManager.shared.searchRecipes(
                    searchText: searchText,
                    ingredients: ingredientsList,
                    categoryId: selectedCategoryId,
                    cuisineId: selectedCuisineId,
                    maxMinutes: maxMinutes,
                    onlyEasy: false
                )

                DispatchQueue.main.async {
                    results = found
                    isSearching = false
                }

            } catch {
                DispatchQueue.main.async {
                    errorText = error.localizedDescription
                    results = []
                    isSearching = false
                }
            }
        }
    }

    private func surpriseMe() {

        do {
            let maxMinutes = filter30 ? 30 : nil

            surpriseRecipeId = try DatabaseManager.shared.randomRecipeId(
                searchText: searchMode == .recipes ? query : "",
                ingredients: searchMode == .ingredients ? selectedIngredients : nil,
                categoryId: selectedCategoryId,
                cuisineId: selectedCuisineId,
                maxMinutes: maxMinutes,
                onlyEasy: false
            )

        } catch {
            errorText = error.localizedDescription
        }
    }

    private var surpriseBinding: Binding<Bool> {
        Binding(
            get: { surpriseRecipeId != nil },
            set: { if !$0 { surpriseRecipeId = nil } }
        )
    }

    // MARK: - Load

    private func loadCategories() {
        categories = (try? DatabaseManager.shared.fetchCategories()) ?? []
    }

    private func loadCuisines() {
        cuisines = (try? DatabaseManager.shared.fetchCuisines()) ?? []
    }
}
