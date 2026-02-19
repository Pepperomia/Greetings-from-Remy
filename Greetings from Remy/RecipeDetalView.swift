import SwiftUI

struct RecipeDetailView: View {
    // MARK: - Properties
    
    let recipeId: Int
    let title: String
    
    // MARK: - State
    
    @State private var detail: RecipeDetail?
    @State private var ingredients: [IngredientLine] = []
    @State private var userData: UserRecipeData?
    @State private var comments: [RecipeComment] = []
    
    @State private var newCommentText = ""
    @State private var isSendingComment = false
    
    @State private var errorText: String?
    @State private var showEdit = false
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            AppBackground(.detail)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let detail = detail {
                        headerView(detail)
                        ingredientsView
                        instructionsView(detail)
                        commentsView
                        editButton
                    } else if let errorText = errorText {
                        errorView(errorText)
                    } else {
                        loadingView
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Рецепт")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadData)
        .sheet(isPresented: $showEdit, onDismiss: loadData) {
            EditRecipeView(recipeId: recipeId)
        }
    }
    
    // MARK: - Header
    
    private func headerView(_ detail: RecipeDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(detail.title)
                .font(.largeTitle.bold())
                .padding(.bottom, 4)
            
            // Используем metaLine из самого detail
            Text(detail.metaLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            
            actionButtonsView
            
            categoryView(detail)
        }
    }
    
    private var actionButtonsView: some View {
        HStack(spacing: 16) {
            favoriteButton
            cookedButton
            cookedCountView
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    private var favoriteButton: some View {
        Button(action: toggleFavorite) {
            Image(systemName: (userData?.isFavorite ?? false) ? "heart.fill" : "heart")
                .font(.title3)
                .foregroundStyle(userData?.isFavorite == true ? .red : .primary)
                .symbolEffect(.bounce, value: userData?.isFavorite)
        }
        .buttonStyle(.plain)
    }
    
    private var cookedButton: some View {
        Button(action: markCooked) {
            Text("Готовила +1")
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.regularMaterial)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var cookedCountView: some View {
        if let count = userData?.cookedCount, count > 0 {
            Text("Готовила: \(count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.regularMaterial)
                .clipShape(Capsule())
        }
    }
    
    private func categoryView(_ detail: RecipeDetail) -> some View {
        HStack {
            Text("Категория:")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(detail.categoryName)
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.regularMaterial)
                .clipShape(Capsule())
        }
    }
    
    // MARK: - Ingredients
    
    private var ingredientsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Ингредиенты")
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(ingredients) { ingredient in
                    ingredientRow(ingredient)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .glassCard()
    }
    
    private func ingredientRow(_ ingredient: IngredientLine) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("•")
                .foregroundStyle(.secondary)
                .font(.body)
            
            Text(ingredient.name)
                .font(.body)
            
            Spacer()
            
            Text(ingredient.amountText)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Instructions
    
    private func instructionsView(_ detail: RecipeDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Приготовление")
            
            Text(detail.instructions)
                .font(.body)
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .glassCard()
    }
    
    // MARK: - Comments
    
    private var commentsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Комментарии")
            
            newCommentView
            
            if comments.isEmpty {
                emptyCommentsView
            } else {
                commentsListView
            }
        }
    }
    
    private var newCommentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Добавить комментарий...", text: $newCommentText, axis: .vertical)
                .lineLimit(2...4)
                .padding(.horizontal, 12)
                .padding(.top, 12)
            
            Button(action: addComment) {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text(isSendingComment ? "Отправка..." : "Отправить")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .foregroundColor(.primary)
            .background(
                Capsule()
                    .fill(.regularMaterial)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .disabled(isSendingComment || newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .glassCard()
    }
    
    private var emptyCommentsView: some View {
        Text("Пока нет комментариев. Будьте первым!")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 24)
            .glassCard()
    }
    
    private var commentsListView: some View {
        ForEach(comments) { comment in
            commentRow(comment)
        }
    }
    
    private func commentRow(_ comment: RecipeComment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(comment.text)
                .font(.body)
            
            Text(comment.createdAtText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassCard()
    }
    
    // MARK: - Edit Button
    
    private var editButton: some View {
        Button(action: { showEdit = true }) {
            HStack {
                Image(systemName: "pencil")
                Text("Редактировать")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundColor(.primary)
        }
        .glassCard()
        .padding(.top, 8)
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.horizontal, 12)
            .padding(.top, 12)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            Text(error)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .glassCard()
    }
    
    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 40)
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        do {
            errorText = nil
            detail = try DatabaseManager.shared.fetchRecipeDetail(recipeId: recipeId)
            ingredients = try DatabaseManager.shared.fetchIngredients(recipeId: recipeId)
            userData = try DatabaseManager.shared.fetchUserRecipeData(recipeId: recipeId)
            comments = try DatabaseManager.shared.fetchComments(recipeId: recipeId)
            
            print("✅ Загружен рецепт: \(detail?.title ?? "")")
            print("   Ингредиентов: \(ingredients.count)")
            print("   Комментариев: \(comments.count)")
            
        } catch {
            errorText = error.localizedDescription
            print("❌ Ошибка загрузки: \(error)")
        }
    }
    
    // MARK: - Actions
    
    private func addComment() {
        let text = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        isSendingComment = true
        
        do {
            try DatabaseManager.shared.addComment(recipeId: recipeId, text: text)
            newCommentText = ""
            comments = try DatabaseManager.shared.fetchComments(recipeId: recipeId)
        } catch {
            errorText = error.localizedDescription
        }
        
        isSendingComment = false
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

// MARK: - Preview

#Preview {
    RecipeDetailView(recipeId: 1, title: "Тестовый рецепт")
}
