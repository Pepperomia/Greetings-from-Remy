import SwiftUI

struct RecipeDetailView: View {

    let recipeId: Int

    @State private var detail: RecipeDetail?
    @State private var ingredients: [IngredientLine] = []
    @State private var errorText: String?

    var body: some View {

        ZStack {

            AppBackground(.detail)

            ScrollView {

                VStack(alignment: .leading, spacing: 18) {

                    if let detail = detail {

                        header(detail)

                        ingredientsSection

                        instructionsSection(detail)

                    }
                    else if let errorText = errorText {

                        errorView(errorText)

                    }
                    else {

                        loadingView
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Рецепт")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { load() }
    }
}

// MARK: HEADER

private extension RecipeDetailView {

    func header(_ detail: RecipeDetail) -> some View {

        VStack(alignment: .leading, spacing: 10) {

            Text(detail.title)
                .font(.largeTitle.bold())

            Text(detail.metaLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            categoryCuisine(detail)
        }
    }

    func categoryCuisine(_ detail: RecipeDetail) -> some View {

        HStack(spacing: 8) {

            Text(detail.categoryName)
                .font(.caption.bold())
                .padding(.horizontal,8)
                .padding(.vertical,4)
                .background(.regularMaterial)
                .clipShape(Capsule())

            if let cuisine = detail.cuisineName,
               !cuisine.isEmpty {

                Text(cuisine)
                    .font(.caption)
                    .padding(.horizontal,8)
                    .padding(.vertical,4)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: INGREDIENTS

private extension RecipeDetailView {

    var ingredientsSection: some View {

        VStack(alignment: .leading, spacing: 12) {

            sectionHeader("Ингредиенты")

            ForEach(ingredients) { ingredient in

                HStack(alignment:.firstTextBaseline) {

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text(ingredient.name)

                    Spacer()

                    Text(ingredient.amountText)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .glassCard()
    }
}

// MARK: INSTRUCTIONS

private extension RecipeDetailView {

    func instructionsSection(_ detail: RecipeDetail) -> some View {

        VStack(alignment:.leading, spacing:12) {

            sectionHeader("Приготовление")

            Text(formatSteps(detail.instructions))
                .textSelection(.enabled)
        }
        .glassCard()
    }

    func formatSteps(_ text:String)->String {

        let steps = text
            .components(separatedBy:"|")
            .map { $0.trimmingCharacters(in:.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if steps.count > 1 {

            return steps.enumerated()
                .map { "\($0+1). \($1)" }
                .joined(separator:"\n\n")
        }

        return text
    }
}

// MARK: HELPERS

private extension RecipeDetailView {

    func sectionHeader(_ title:String)->some View {

        Text(title)
            .font(.headline)
    }

    var loadingView: some View {

        ProgressView()
            .frame(maxWidth:.infinity)
            .padding(.vertical,40)
    }

    func errorView(_ text:String)->some View {

        Text(text)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding()
    }

    func load() {

        do {

            detail = try DatabaseManager.shared.fetchRecipeDetail(recipeId: recipeId)

            ingredients = try DatabaseManager.shared.fetchIngredients(recipeId: recipeId)

        }
        catch {

            errorText = error.localizedDescription
        }
    }
}
