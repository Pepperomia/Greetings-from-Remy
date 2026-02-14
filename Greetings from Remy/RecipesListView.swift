import SwiftUI

struct RecipesListView: View {
    let category: CategoryRow

    @State private var items: [RecipeRow] = []
    @State private var errorText: String?

    @State private var cuisines: [CuisineRow] = []
    @State private var selectedCuisineId: Int? = nil

    @State private var filter30 = false
    @State private var surpriseRecipeId: Int? = nil

    // Добавление кухни
    @State private var showAddCuisine = false

    var body: some View {
        ZStack {
            AppBackground(.detail) // если нет режимов — AppBackground()

            VStack(spacing: 12) {

                // Фильтры (кухня + добавить + до 30 + удиви меня)
                VStack(spacing: 10) {

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
                        .accessibilityLabel("Добавить кухню")
                    }

                    HStack(spacing: 10) {
                        Toggle("до 30 мин", isOn: $filter30)
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
                }
                .padding(.horizontal)

                // Список рецептов
                List(items) { r in
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
        .navigationTitle(category.name)
        .toolbar {
            Button("Сброс") { resetFilters() }
        }
        .navigationDestination(item: $surpriseRecipeId) { id in
            RecipeDetailView(recipeId: id, title: "Рецепт")
        }
        .sheet(isPresented: $showAddCuisine) {
            // Этот sheet мы делали отдельным файлом AddCuisineSheet.swift
            AddCuisineSheet {
                // после добавления кухни обновим список кухонь
                loadCuisines()
            }
        }
        .onAppear {
            loadCuisines()
            load()
        }
        .onChange(of: selectedCuisineId) { _, _ in load() }
        .onChange(of: filter30) { _, _ in load() }
        .overlay(alignment: .center) {
            if let errorText {
                Text("Ошибка: \(errorText)")
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
            }
        }
    }

    private func resetFilters() {
        selectedCuisineId = nil
        filter30 = false
        load()
    }

    private func loadCuisines() {
        do {
            errorText = nil

            // ВАЖНО:
            // fetchCuisines() возвращает только кухни, у которых есть рецепты (по твоей текущей версии DB).
            // Это идеально для фильтра: не показываем “пустые” кухни.
            // Плюс мягко скрываем варианты с маленькой буквы, чтобы не было дублей/мусора.
            let all = try DatabaseManager.shared.fetchCuisines()
            cuisines = all.filter { cuisine in
                guard let first = cuisine.name.first,
                      let scalar = first.unicodeScalars.first else { return true }
                return !CharacterSet.lowercaseLetters.contains(scalar)
            }

        } catch {
            errorText = "Ошибка кухонь: \(error.localizedDescription)"
            cuisines = []
        }
    }

    private func load() {
        do {
            errorText = nil
            let maxMin = filter30 ? 30 : nil

            items = try DatabaseManager.shared.searchRecipes(
                query: "",
                categoryId: category.id,
                cuisineId: selectedCuisineId,
                maxMinutes: maxMin,
                onlyEasy: false
            )
        } catch {
            errorText = error.localizedDescription
            items = []
        }
    }

    private func surpriseMe() {
        do {
            errorText = nil
            let maxMin = filter30 ? 30 : nil

            if let id = try DatabaseManager.shared.randomRecipeId(
                query: "",
                categoryId: category.id,
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
}
