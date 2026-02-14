import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var results: [RecipeRow] = []
    @State private var errorText: String?

    @State private var categories: [CategoryRow] = []
    @State private var selectedCategoryId: Int? = nil

    @State private var cuisines: [CuisineRow] = []
    @State private var selectedCuisineId: Int? = nil

    @State private var surpriseRecipeId: Int? = nil

    @State private var filter30 = false
    @State private var onlyEasy = false

    @State private var showAddCuisine = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 12) {

                    TextField("Поиск: борщ, курица, сливки…", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)

                    // Категория
                    Picker("Категория", selection: Binding(
                        get: { selectedCategoryId ?? -1 },
                        set: { selectedCategoryId = ($0 == -1 ? nil : $0) }
                    )) {
                        Text("Все").tag(-1)
                        ForEach(categories) { c in
                            Text(c.name).tag(c.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal)

                    // Кухня + кнопка добавить
                    HStack(spacing: 8) {
                        Picker("Кухня", selection: Binding(
                            get: { selectedCuisineId ?? -1 },
                            set: { selectedCuisineId = ($0 == -1 ? nil : $0) }
                        )) {
                            Text("Все кухни").tag(-1)
                            ForEach(cuisines) { c in
                                Text(c.name).tag(c.id)
                            }
                        }
                        .pickerStyle(.menu)

                        Button {
                            showAddCuisine = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)

                    // Быстрые фильтры + Удиви меня
                    HStack(spacing: 10) {
                        Toggle("до 30 мин", isOn: $filter30)
                            .toggleStyle(.button)

                        Toggle("легко", isOn: $onlyEasy)
                            .toggleStyle(.button)

                        Spacer()

                        Button {
                            surpriseMe()
                        } label: {
                            HStack(spacing: 8) {
                                Image("mouse_clover")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)
                                Text("Удиви меня")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.mint)
                    }
                    .padding(.horizontal)

                    // Результаты
                    List(results) { r in
                        NavigationLink {
                            RecipeDetailView(recipeId: r.id, title: r.title)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(r.title)
                                HStack(spacing: 10) {
                                    Text("\(r.timeMinutes) мин")
                                    Text(diffLabel(r.difficulty))
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Поиск")
            .toolbar {
                Button("Сброс") { resetFilters() }
            }
            .navigationDestination(item: $surpriseRecipeId) { id in
                RecipeDetailView(recipeId: id, title: "Рецепт")
            }
            .onAppear {
                loadCategories()
                loadCuisines()
                runSearch()
            }
            .onChange(of: query) { _, _ in runSearch() }
            .onChange(of: filter30) { _, _ in runSearch() }
            .onChange(of: onlyEasy) { _, _ in runSearch() }
            .onChange(of: selectedCategoryId) { _, _ in runSearch() }
            .onChange(of: selectedCuisineId) { _, _ in runSearch() }
            .sheet(isPresented: $showAddCuisine) {
                AddCuisineSheet {
                    loadCuisines()
                }
            }
            .overlay(alignment: .center) {
                if let errorText {
                    Text(errorText)
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding()
                }
            }
        }
    }

    private func resetFilters() {
        query = ""
        filter30 = false
        onlyEasy = false
        selectedCategoryId = nil
        selectedCuisineId = nil
        runSearch()
    }

    private func runSearch() {
        do {
            errorText = nil
            let maxMin = filter30 ? 30 : nil

            results = try DatabaseManager.shared.searchRecipes(
                query: query,
                categoryId: selectedCategoryId,
                cuisineId: selectedCuisineId,
                maxMinutes: maxMin,
                onlyEasy: onlyEasy
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
                categoryId: selectedCategoryId,
                cuisineId: selectedCuisineId,
                maxMinutes: maxMin,
                onlyEasy: onlyEasy
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
}
