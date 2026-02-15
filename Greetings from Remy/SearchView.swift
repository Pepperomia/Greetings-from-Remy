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

                VStack(spacing: 12) {

                    // Поисковая строка
                    TextField("Поиск: борщ, курица, сливки…", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal, UI.sidePad)
                        .padding(.top, UI.topPad)

                    // ✅ Мышиные фильтры
                    filtersRow
                        .padding(.horizontal, UI.sidePad)

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

            // ✅ вместо navigationDestination(item:) (Int не Identifiable)
            .navigationDestination(isPresented: Binding(
                get: { surpriseRecipeId != nil },
                set: { if !$0 { surpriseRecipeId = nil } }
            )) {
                RecipeDetailView(recipeId: surpriseRecipeId ?? 0, title: "Рецепт")
            }

            .onAppear {
                loadCategories()
                loadCuisines()
                runSearch()
            }
            .onChange(of: query) { _, _ in runSearch() }
            .onChange(of: filter30) { _, _ in runSearch() }
            .onChange(of: selectedCategoryId) { _, _ in runSearch() }
            .onChange(of: selectedCuisineId) { _, _ in runSearch() }

            .sheet(isPresented: $showAddCuisine) {
                AddCuisineSheet { loadCuisines() }
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

    // MARK: - Filters row (мыши)

    private var filtersRow: some View {
        HStack(spacing: 14) {

            // 1) watch
            Button {
                filter30.toggle()
            } label: {
                MouseSticker("mouse_watch", size: UI.mouseSize)
                    .opacity(filter30 ? 1.0 : 0.55)
            }
            .buttonStyle(.plain)

            // 2) cube
            Button {
                surpriseMe()
            } label: {
                MouseSticker("mouse_cube", size: UI.mouseSize)
            }
            .buttonStyle(.plain)

            // 3) book (категории)
            Menu {
                Button("Все") { selectedCategoryId = nil }
                Divider()
                ForEach(categories) { c in
                    Button(c.name) { selectedCategoryId = c.id }
                }
            } label: {
                MouseSticker("mouse_book", size: UI.mouseSize)
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
                    .background(.thinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
    }

    private var tinyChevron: some View {
        Image(systemName: "chevron.down")
            .font(.caption2.weight(.semibold))
            .padding(6)
            .background(.thinMaterial)
            .clipShape(Circle())
            .offset(x: 6, y: 6)
    }

    // MARK: - Data

    private func resetFilters() {
        query = ""
        filter30 = false
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
                onlyEasy: false // (4) "легко" удалили, значит всегда false
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
                .clipped()
                .accessibilityHidden(true)
        }
    }
}
