import SwiftUI

struct RecipesListView: View {

    let category: CategoryRow

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
        .navigationDestination(isPresented: surpriseBinding) {
            if let id = surpriseRecipeId {
                RecipeDetailView(recipeId: id)
            }
        }
        .onAppear {
            loadRecipes()
        }
        .onChange(of: filter30) { _, _ in
            loadRecipes()
        }
    }

    // MARK: - Bindings

    private var surpriseBinding: Binding<Bool> {
        Binding(
            get: { surpriseRecipeId != nil },
            set: { if !$0 { surpriseRecipeId = nil } }
        )
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

                    Image("mouse_watch")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 70, height: 70)

                    Text("до 30 мин")
                        .font(.caption)
                }
            }

            Button {
                surpriseMe()
            } label: {

                VStack {

                    Image("mouse_cube")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 70, height: 70)

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
                        timeText: recipe.timeText ?? "",
                        difficultyText: recipe.difficultyText ?? ""
                    )
                }
            }
        }
        .padding(.horizontal)
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

                let maxMinutes = filter30 ? 30 : nil

                let recipes = try DatabaseManager.shared.fetchRecipes(
                    categoryId: category.id,
                    maxMinutes: maxMinutes
                )

                DispatchQueue.main.async {

                    self.items = recipes
                    self.isLoading = false
                }

            } catch {

                DispatchQueue.main.async {

                    self.errorText = error.localizedDescription
                    self.isLoading = false
                }
            }
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
    let timeText: String
    let difficultyText: String

    var body: some View {

        HStack {

            VStack(alignment: .leading, spacing: 6) {

                Text(title)
                    .font(.headline)

                HStack(spacing: 8) {

                    Text(timeText)
                        .font(.subheadline)

                    if !timeText.isEmpty && !difficultyText.isEmpty {
                        Text("•")
                            .foregroundStyle(.secondary)
                    }

                    Text(difficultyText)
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
    }
}

// MARK: - Preview

#Preview {

    NavigationStack {

        RecipesListView(
            category: CategoryRow(
                id: 1,
                name: "Салаты",
                count: 5
            )
        )
    }
}
