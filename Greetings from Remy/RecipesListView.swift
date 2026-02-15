import SwiftUI

struct RecipesListView: View {
    let category: CategoryRow

    @State private var items: [RecipeRow] = []
    @State private var errorText: String?

    @State private var cuisines: [CuisineRow] = []
    @State private var selectedCuisineId: Int? = nil

    @State private var filter30 = false
    @State private var surpriseRecipeId: Int? = nil

    @State private var showAddCuisine = false

    var body: some View {
        ZStack {
            AppBackground(.detail)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {

                    // ФИЛЬТРЫ-МЫШИ (одна линия)
                    filtersRow
                        .padding(.top, 6)

                    // КАРТОЧКИ РЕЦЕПТОВ
                    LazyVStack(spacing: 14) {
                        ForEach(items) { r in
                            NavigationLink {
                                RecipeDetailView(recipeId: r.id, title: r.title)
                            } label: {
                                RecipeCardRow(
                                    title: r.title,
                                    subtitle: "\(r.timeMinutes) мин  •  \(diffLabel(r.difficulty))"
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, UI.headerSidePadding)
                        }
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 28)
                }
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
            AddCuisineSheet {
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
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding()
            }
        }
    }

    // MARK: - Filters row (mice)

    private var filtersRow: some View {
        HStack {
            // ЛЕВЫЙ БЛОК: watch + world
            HStack(spacing: 12) {

                // до 30 минут
                Button {
                    filter30.toggle()
                    load()
                } label: {
                    MouseSticker("mouse_watch", size: UI.filterMouseSize)
                        .overlay(
                            RoundedRectangle(cornerRadius: UI.ringCorner, style: .continuous)
                                .stroke(.white.opacity(filter30 ? UI.selectedRingOpacity : 0), lineWidth: 2)
                        )
                        .scaleEffect(filter30 ? 1.05 : 1.0)
                        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: filter30)
                }
                .buttonStyle(.plain)

                

            // ЦЕНТР: кубик
            Button {
                surpriseMe()
            } label: {
                MouseSticker("mouse_cube", size: UI.filterMouseSize)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
                
                // кухни мира (меню)
                Menu {
                    Button("Все кухни") {
                        selectedCuisineId = nil
                        load()
                    }

                    ForEach(cuisines) { c in
                        Button(c.name) {
                            selectedCuisineId = c.id
                            load()
                        }
                    }
                } label: {
                    MouseSticker("mouse_world", size: UI.filterMouseSize)
                        .overlay(
                            RoundedRectangle(cornerRadius: UI.ringCorner, style: .continuous)
                                .stroke(.white.opacity(selectedCuisineId != nil ? UI.selectedRingOpacity : 0), lineWidth: 2)
                        )
                        .scaleEffect(selectedCuisineId != nil ? 1.04 : 1.0)
                        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: selectedCuisineId != nil)
                }
            }

            Spacer(minLength: 0)

            // ПРАВЫЙ БЛОК: плюс
            Button {
                showAddCuisine = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, UI.headerSidePadding)
    }

    // MARK: - Data

    private func resetFilters() {
        selectedCuisineId = nil
        filter30 = false
        load()
    }

    private func loadCuisines() {
        do {
            errorText = nil
            let all = try DatabaseManager.shared.fetchCuisines()

            // мягко убираем “мусорные” (с маленькой буквы)
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

// MARK: - UI helpers

private enum UI {
    static let filterMouseSize: CGFloat = 85
    static let headerSidePadding: CGFloat = 16

    static let cardRadius: CGFloat = 22
    static let cardOpacity: Double = 0.55
    static let cardVPad: CGFloat = 14
    static let cardHPad: CGFloat = 16

    static let selectedRingOpacity: Double = 0.35
    static let ringCorner: CGFloat = 16
}

private struct MouseSticker: View {
    let name: String
    let size: CGFloat

    init(_ name: String, size: CGFloat) {
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

private struct RecipeCardRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary.opacity(0.8))
        }
        .padding(.vertical, UI.cardVPad)
        .padding(.horizontal, UI.cardHPad)
        .glassCard(radius: UI.cardRadius, opacity: UI.cardOpacity)
    }
}
