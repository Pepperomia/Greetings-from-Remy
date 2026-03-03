import SwiftUI

struct FavoritesView: View {

    private enum Constants {
        static let headerSidePadding: CGFloat = 20
    }

    @State private var items: [RecipeRow] = []
    @State private var errorText: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground(.list)

                ScrollView {
                    VStack(spacing: 20) {

                        header

                        if isLoading {
                            ProgressView()
                                .padding(.top, 40)
                        }
                        else if let errorText {
                            Text(errorText)
                                .foregroundStyle(.red)
                                .padding(.top, 40)
                        }
                        else if items.isEmpty {
                            Text("Пока нет избранных рецептов")
                                .padding(.top, 40)
                                .foregroundStyle(.secondary)
                        }
                        else {
                            list
                        }
                    }
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Избранное")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: load) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                load()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 16) {

            Image(systemName: "heart.fill")
                .font(.system(size: 40))
                .foregroundStyle(.pink)

            VStack(alignment: .leading) {
                Text("Избранное")
                    .font(.title3.bold())

                if !items.isEmpty {
                    Text("\(items.count) рецептов")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, Constants.headerSidePadding)
        .padding(.top, 10)
    }

    // MARK: - List

    private var list: some View {
        LazyVStack(spacing: 12) {
            ForEach(items) { recipe in
                NavigationLink {
                    RecipeDetailView(recipeId: recipe.id)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(recipe.title)
                            .font(.headline)

                        Text(recipe.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .glassCard()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Constants.headerSidePadding)
            }
        }
    }

    // MARK: - Data

    private func load() {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Временно используем категорию 1 как "избранное"
                let recipes = try DatabaseManager.shared.fetchRecipes(categoryId: 1)

                DispatchQueue.main.async {
                    items = recipes
                    errorText = nil
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
}
