import SwiftUI

struct SearchView: View {

    @State private var query: String = ""
    @State private var results: [RecipeRow] = []

    @State private var isSearching = false
    @State private var errorText: String?

    var body: some View {

        ZStack {

            AppBackground()

            ScrollView {

                VStack(spacing: 16) {

                    searchField

                    if isSearching {
                        ProgressView()
                            .padding(.top, 20)
                    }

                    if let errorText {
                        Text(errorText)
                            .foregroundStyle(.red)
                            .padding(.top, 20)
                    }

                    if results.isEmpty && !query.isEmpty && !isSearching {
                        Text("Ничего не найдено")
                            .foregroundStyle(.secondary)
                            .padding(.top, 30)
                    }

                    resultsList
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Поиск")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Search Field

private extension SearchView {

    var searchField: some View {

        TextField("борщ, курица, сливки…", text: $query)
            .textFieldStyle(.roundedBorder)
            .onSubmit {
                runSearch()
            }
    }
}

// MARK: - Results

private extension SearchView {

    var resultsList: some View {

        LazyVStack(spacing: 12) {

            ForEach(results) { recipe in

                NavigationLink {

                    RecipeDetailView(recipeId: recipe.id)

                } label: {

                    HStack {

                        VStack(alignment: .leading, spacing: 6) {

                            Text(recipe.title)
                                .font(.headline)

                            HStack(spacing: 8) {

                                Text(recipe.timeText)
                                    .font(.subheadline)

                                if !recipe.timeText.isEmpty && !recipe.difficultyText.isEmpty {
                                    Text("•")
                                        .foregroundStyle(.secondary)
                                }

                                Text(recipe.difficultyText)
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
        }
    }
}

// MARK: - Search Logic

private extension SearchView {

    func runSearch() {

        let text = query.trimmingCharacters(in: .whitespaces)

        guard !text.isEmpty else {
            results = []
            return
        }

        isSearching = true
        errorText = nil

        DispatchQueue.global(qos: .userInitiated).async {

            do {

                let found = try DatabaseManager.shared.searchRecipes(query: text)

                DispatchQueue.main.async {

                    self.results = found
                    self.isSearching = false
                }

            } catch {

                DispatchQueue.main.async {

                    self.errorText = error.localizedDescription
                    self.isSearching = false
                }
            }
        }
    }
}
