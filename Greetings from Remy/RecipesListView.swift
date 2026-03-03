import SwiftUI

struct RecipesListView: View {

    let category: CategoryRow

    @State private var allItems: [RecipeRow] = []
    @State private var items: [RecipeRow] = []
    @State private var errorText: String?

    @State private var filter30 = false
    @State private var surpriseRecipeId: Int?

    @State private var isLoading = false

    var body: some View {
        ZStack {
            AppBackground(.list)

            ScrollView {
                VStack(spacing: 20) {

                    filtersRow

                    if isLoading {
                        ProgressView()
                            .padding(.top, 40)
                    }
                    else if let errorText {
                        errorView(errorText)
                    }
                    else if items.isEmpty {
                        emptyView
                    }
                    else {
                        recipesList
                    }
                }
                .padding(.bottom, 28)
            }
        }
        .navigationTitle(category.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $surpriseRecipeId) { id in
            RecipeDetailView(recipeId: id)
        }
        .onAppear {
            loadRecipes()
        }
        .onChange(of: filter30) { _, _ in
            applyFilters()
        }
    }
}

// MARK: - Filters

private extension RecipesListView {

    var filtersRow: some View {
        HStack(spacing: 40) {

            Button {
                filter30.toggle()
            } label: {
                VStack {
                    Image(systemName: "clock")
                        .font(.title2)
                    Text("до 30 мин")
                        .font(.caption)
                }
            }

            Button {
                surpriseMe()
            } label: {
                VStack {
                    Image(systemName: "dice")
                        .font(.title2)
                    Text("Сюрприз")
                        .font(.caption)
                }
            }
        }
        .padding(.top, 12)
    }
}

// MARK: - List

private extension RecipesListView {

    var recipesList: some View {
        LazyVStack(spacing: 12) {
            ForEach(items) { recipe in
                NavigationLink {
                    RecipeDetailView(recipeId: recipe.id)
                } label: {
                    RecipeCardRow(
                        title: recipe.title,
                        subtitle: recipe.subtitle
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    var emptyView: some View {
        Text("Нет рецептов")
            .padding(.top, 40)
    }

    func errorView(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.red)
            .padding(.top, 40)
    }
}

// MARK: - Data

private extension RecipesListView {

    func loadRecipes() {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let recipes = try DatabaseManager.shared.fetchRecipes(categoryId: category.id)

                DispatchQueue.main.async {
                    allItems = recipes
                    applyFilters()
                    isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    errorText = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    func applyFilters() {
        if filter30 {
            items = allItems.filter {
                Int($0.timeText.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 0 <= 30
            }
        } else {
            items = allItems
        }
    }

    func surpriseMe() {
        guard !items.isEmpty else { return }
        surpriseRecipeId = items.randomElement()?.id
    }
}

// MARK: - Card

private struct RecipeCardRow: View {

    let title: String
    let subtitle: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
        )
    }
}
