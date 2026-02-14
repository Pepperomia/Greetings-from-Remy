import SwiftUI

struct EditRecipeView: View {
    let recipeId: Int
    var onSaved: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var categories: [CategoryRow] = []
    @State private var selectedCategoryId: Int = -1

    @State private var title = ""
    @State private var cuisine = ""
    @State private var timeText = ""
    @State private var servings = ""
    @State private var difficulty = "medium"

    @State private var ingredientsText = ""
    @State private var instructions = ""

    @State private var errorText: String?
    @State private var successText: String?

    // Comments
    @State private var comments: [RecipeComment] = []
    @State private var editingCommentId: Int? = nil
    @State private var editingCommentText: String = ""
    @State private var commentsError: String? = nil

    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground(.detail) // или AppBackground()

                Form {
                    Section("Основное") {
                        TextField("Название", text: $title)

                        Picker("Категория", selection: $selectedCategoryId) {
                            ForEach(categories) { c in
                                Text(c.name).tag(c.id)
                            }
                        }

                        TextField("Кухня (опционально)", text: $cuisine)

                        Picker("Сложность", selection: $difficulty) {
                            Text("легко").tag("easy")
                            Text("средне").tag("medium")
                            Text("сложно").tag("hard")
                        }
                        .pickerStyle(.segmented)

                        TextField("Время (мин)", text: $timeText)
                            .keyboardType(.numberPad)

                        TextField("Порции (опционально)", text: $servings)
                    }

                    Section("Ингредиенты") {
                        Text("Каждая строка: Ингредиент — Количество")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $ingredientsText)
                            .frame(minHeight: 140)
                    }

                    Section("Шаги") {
                        TextEditor(text: $instructions)
                            .frame(minHeight: 180)
                    }

                    // --- Комментарии (редактирование прямо тут) ---
                    Section("Комментарии") {
                        if let commentsError {
                            Text("Ошибка: \(commentsError)")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }

                        if comments.isEmpty {
                            Text("Пока нет комментариев.")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        } else {
                            ForEach(comments) { c in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(c.createdAtText)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        Spacer()

                                        Button {
                                            startEdit(c)
                                        } label: {
                                            Image(systemName: "pencil")
                                        }

                                        Button(role: .destructive) {
                                            removeComment(c)
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                    }

                                    if editingCommentId == c.id {
                                        TextField("Комментарий", text: $editingCommentText, axis: .vertical)
                                            .lineLimit(2...6)

                                        HStack {
                                            Button("Отмена") { cancelEdit() }
                                                .buttonStyle(.bordered)

                                            Spacer()

                                            Button("Сохранить") { saveEdit() }
                                                .buttonStyle(.borderedProminent)
                                                .tint(.mint)
                                                .disabled(editingCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                        }
                                    } else {
                                        Text(c.text)
                                            .font(.body)
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    }

                    // Ошибки/успех
                    if let errorText {
                        Section { Text(errorText).foregroundStyle(.red) }
                    }
                    if let successText {
                        Section { Text(successText).foregroundStyle(.green) }
                    }

                    // Удаление (ВАЖНО: внутри Form)
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Text("Удалить рецепт")
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Редактировать")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") { save() }
                }
            }
            .onAppear { loadAll() }
            .confirmationDialog("Удалить рецепт?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) {
                    deleteRecipe()
                }
                Button("Отмена", role: .cancel) { }
            } message: {
                Text("Рецепт будет скрыт из каталогов и поиска. (Можно будет вернуть позже, если захотим.)")
            }
        }
    }

    // MARK: - Load

    private func loadAll() {
        do {
            errorText = nil
            successText = nil

            categories = try DatabaseManager.shared.fetchCategories()
            let d = try DatabaseManager.shared.fetchRecipeDetail(recipeId: recipeId)
            let ing = try DatabaseManager.shared.fetchIngredients(recipeId: recipeId)

            title = d.title
            cuisine = d.cuisineName ?? ""
            difficulty = d.difficulty
            timeText = d.timeMinutes > 0 ? "\(d.timeMinutes)" : ""
            servings = d.servingsText ?? ""
            instructions = d.instructions

            if let cat = categories.first(where: { $0.name == d.categoryName }) {
                selectedCategoryId = cat.id
            } else if selectedCategoryId == -1, let first = categories.first {
                selectedCategoryId = first.id
            }

            ingredientsText = ing.map { "\($0.name) — \($0.amountText)" }.joined(separator: "\n")

            loadComments()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func loadComments() {
        do {
            commentsError = nil
            comments = try DatabaseManager.shared.fetchComments(recipeId: recipeId)
        } catch {
            commentsError = error.localizedDescription
            comments = []
        }
    }

    // MARK: - Save recipe

    private func save() {
        do {
            errorText = nil
            successText = nil

            let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanTitle.isEmpty {
                errorText = "Название не может быть пустым"
                return
            }

            let timeMinutes = Int(timeText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            let cleanInstructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanInstructions.isEmpty {
                errorText = "Добавь шаги приготовления"
                return
            }

            let lines = ingredientsText
                .split(separator: "\n")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let cleanCuisine = cuisine.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanServings = servings.trimmingCharacters(in: .whitespacesAndNewlines)

            try DatabaseManager.shared.updateRecipe(
                recipeId: recipeId,
                title: cleanTitle,
                categoryId: selectedCategoryId,
                cuisineName: cleanCuisine.isEmpty ? nil : cleanCuisine,
                difficulty: difficulty,
                timeMinutes: timeMinutes,
                servingsText: cleanServings.isEmpty ? nil : cleanServings,
                instructions: cleanInstructions,
                ingredientsLines: lines
            )

            successText = "Сохранено ✅"
            onSaved?()
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }

    // MARK: - Delete recipe

    private func deleteRecipe() {
        do {
            errorText = nil
            try DatabaseManager.shared.archiveRecipe(recipeId: recipeId)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }

    // MARK: - Comments edit helpers

    private func startEdit(_ c: RecipeComment) {
        editingCommentId = c.id
        editingCommentText = c.text
        commentsError = nil
    }

    private func cancelEdit() {
        editingCommentId = nil
        editingCommentText = ""
    }

    private func saveEdit() {
        guard let id = editingCommentId else { return }
        let text = editingCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        do {
            commentsError = nil
            try DatabaseManager.shared.updateComment(commentId: id, text: text)
            cancelEdit()
            loadComments()
        } catch {
            commentsError = error.localizedDescription
        }
    }

    private func removeComment(_ c: RecipeComment) {
        do {
            commentsError = nil
            try DatabaseManager.shared.deleteComment(commentId: c.id)
            if editingCommentId == c.id { cancelEdit() }
            loadComments()
        } catch {
            commentsError = error.localizedDescription
        }
    }
}
