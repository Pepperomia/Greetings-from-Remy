import SwiftUI

struct RecipeDetailView: View {
    let recipeId: Int
    let title: String // оставляем для совместимости вызовов, в UI используем detail.title

    @State private var detail: RecipeDetail?
    @State private var ingredients: [IngredientLine] = []
    @State private var errorText: String?
    @State private var userData: UserRecipeData?

    @State private var showEdit = false

    // Comments
    @State private var comments: [RecipeComment] = []
    @State private var newCommentText = ""
    @State private var isSendingComment = false

    var body: some View {
        ZStack {
            AppBackground() // если у тебя есть режимы: AppBackground(.detail)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    if let detail {
                        header(detail)
                        Divider().opacity(0.25)

                        ingredientsBlock
                        Divider().opacity(0.25)

                        instructionsBlock(detail)
                        Divider().opacity(0.25)

                        commentsBlock

                        Button {
                            showEdit = true
                        } label: {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Редактировать")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.mint)
                        .padding(.top, 6)

                    } else if let errorText {
                        Text("Ошибка: \(errorText)")
                            .foregroundStyle(.red)
                            .padding(.top, 30)
                    } else {
                        ProgressView()
                            .padding(.top, 30)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Рецепт")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { load() }
        .sheet(isPresented: $showEdit, onDismiss: {
            load()
        }) {
            EditRecipeView(recipeId: recipeId)
        }
    }

    // MARK: - UI parts

    private func header(_ d: RecipeDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(d.title)
                .font(.title2).bold()

            Text(metaLine(d))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    toggleFavorite()
                } label: {
                    Image(systemName: (userData?.isFavorite ?? false) ? "heart.fill" : "heart")
                        .font(.title3)
                }

                Button("Готовила +1") { markCooked() }
                    .buttonStyle(.bordered)

                if let cnt = userData?.cookedCount {
                    Text("Готовила: \(cnt)")
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.top, 6)

            Text("Категория: \(d.categoryName)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var ingredientsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ингредиенты")
                .font(.headline)

            ForEach(ingredients) { ing in
                HStack(alignment: .firstTextBaseline) {
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text(ing.name)
                    Spacer()
                    Text(ing.amountText)
                        .foregroundStyle(.secondary)
                }
                .font(.body)
                .glassCard()
            }
        }
    }

    private func instructionsBlock(_ d: RecipeDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Приготовление")
                .font(.headline)

            Text(d.instructions)
                .font(.body)
                .textSelection(.enabled)
                .glassCard()
        }
    }

    private var commentsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Комментарии")
                .font(.headline)

            // Ввод комментария
            VStack(alignment: .leading, spacing: 8) {
                TextField("Добавь комментарий", text: $newCommentText, axis: .vertical)
                    .lineLimit(2...4)

                Button {
                    addComment()
                } label: {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text(isSendingComment ? "Сохраняю..." : "Добавить")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.mint)
                .disabled(isSendingComment || newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .glassCard()

            // Список комментариев
            if comments.isEmpty {
                Text("Пока нет комментариев.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(comments) { c in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(c.text)
                            .font(.body)

                        Text(c.createdAtText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .glassCard()
                }
            }
        }
    }

    // MARK: - Data

    private func load() {
        do {
            errorText = nil
            detail = try DatabaseManager.shared.fetchRecipeDetail(recipeId: recipeId)
            ingredients = try DatabaseManager.shared.fetchIngredients(recipeId: recipeId)
            userData = try DatabaseManager.shared.fetchUserRecipeData(recipeId: recipeId)
            comments = try DatabaseManager.shared.fetchComments(recipeId: recipeId)
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func addComment() {
        let text = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        do {
            isSendingComment = true
            errorText = nil

            try DatabaseManager.shared.addComment(recipeId: recipeId, text: text)

            newCommentText = ""
            comments = try DatabaseManager.shared.fetchComments(recipeId: recipeId)

            isSendingComment = false
        } catch {
            isSendingComment = false
            errorText = error.localizedDescription
        }
    }

    private func metaLine(_ d: RecipeDetail) -> String {
        var parts: [String] = []
        if d.timeMinutes > 0 { parts.append("\(d.timeMinutes) мин") }
        parts.append(diffLabel(d.difficulty))
        if let s = d.servingsText, !s.isEmpty { parts.append("Порции: \(s)") }
        if let c = d.cuisineName, !c.isEmpty { parts.append("Кухня: \(c)") }
        return parts.joined(separator: " • ")
    }

    private func diffLabel(_ diff: String) -> String {
        switch diff {
        case "easy": return "легко"
        case "hard": return "сложно"
        default: return "средне"
        }
    }

    private func toggleFavorite() {
        do {
            let current = userData?.isFavorite ?? false
            try DatabaseManager.shared.setFavorite(recipeId: recipeId, isFavorite: !current)
            userData = try DatabaseManager.shared.fetchUserRecipeData(recipeId: recipeId)
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func markCooked() {
        do {
            try DatabaseManager.shared.incrementCookedCount(recipeId: recipeId)
            userData = try DatabaseManager.shared.fetchUserRecipeData(recipeId: recipeId)
        } catch {
            errorText = error.localizedDescription
        }
    }
}
