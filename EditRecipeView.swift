import SwiftUI

struct EditRecipeView: View {

    let recipeId: Int
    var onSaved: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var detail: RecipeDetail?
    @State private var ingredients: [IngredientLine] = []
    @State private var errorText: String?

    var body: some View {

        NavigationStack {

            ZStack {

                AppBackground(.list)

                ScrollView {

                    VStack(spacing: 16) {

                        if let errorText {
                            messageView(text: errorText, color: .red)
                        }

                        if let detail {
                            form(detail)
                        } else {
                            ProgressView()
                                .padding(.top,40)
                        }
                    }
                    .padding(.horizontal,20)
                    .padding(.bottom,20)
                }
            }
            .navigationTitle("Рецепт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {

                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                load()
            }
        }
    }

    // MARK: FORM

    private func form(_ detail: RecipeDetail) -> some View {

        VStack(alignment:.leading, spacing:18) {

            Text(detail.title)
                .font(.title2.bold())

            Text(detail.metaLine)
                .foregroundStyle(.secondary)

            Divider()

            Text("Ингредиенты")
                .font(.headline)

            ForEach(ingredients) { ing in

                HStack {

                    Text("•")

                    Text(ing.name)

                    Spacer()

                    Text(ing.amountText)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Text("Приготовление")
                .font(.headline)

            Text(detail.instructions)
        }
        .padding(18)
        .glassCard()
    }

    // MARK: LOAD

    private func load() {

        do {

            detail = try DatabaseManager.shared.fetchRecipeDetail(
                recipeId: recipeId
            )

            ingredients = try DatabaseManager.shared.fetchIngredients(
                recipeId: recipeId
            )

        } catch {

            errorText = error.localizedDescription
        }
    }

    // MARK: MESSAGE

    private func messageView(text:String,color:Color) -> some View {

        Text(text)
            .font(.caption)
            .foregroundStyle(color)
            .padding(8)
            .frame(maxWidth:.infinity,alignment:.leading)
            .background(.regularMaterial)
            .cornerRadius(8)
    }
}

#Preview {
    EditRecipeView(recipeId:1)
}
