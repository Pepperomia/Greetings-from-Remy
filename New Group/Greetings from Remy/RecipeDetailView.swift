import SwiftUI

struct RecipeDetailView: View {
    
    let recipeId: Int
    
    @State private var detail: RecipeDetail?
    @State private var ingredients: [IngredientLine] = []
    @State private var errorText: String?
    @State private var showingDeleteAlert = false
    @State private var isDeleting = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        
        ZStack {
            
            AppBackground(.detail)
            
            ScrollView {
                
                VStack(alignment: .leading, spacing: 18) {
                    
                    if let detail = detail {
                        
                        header(detail)
                            .padding(.horizontal, 20)
                        
                        nutritionInfo(detail)
                            .padding(.horizontal, 20)
                        
                        ingredientsSection
                            .padding(.horizontal, 20)
                        
                        instructionsSection(detail)
                            .padding(.horizontal, 20)
                        
                        deleteButton
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                            .padding(.bottom, 20)
                    }
                    else if let errorText = errorText {
                        errorView(errorText)
                    }
                    else {
                        loadingView
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Рецепт")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Удаление рецепта", isPresented: $showingDeleteAlert) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                deleteRecipe()
            }
        } message: {
            Text("Вы уверены, что хотите удалить рецепт «\(detail?.title ?? "")»?")
        }
        .onAppear {
            load()
        }
    }
    
    // MARK: DELETE BUTTON
    
    private var deleteButton: some View {
        
        Button {
            showingDeleteAlert = true
        } label: {
            HStack {
                if isDeleting {
                    ProgressView().tint(.red)
                } else {
                    Image(systemName: "trash")
                }
                
                Text("Удалить рецепт")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.regularMaterial)
            .foregroundColor(.red)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.red.opacity(0.3))
            )
        }
        .disabled(isDeleting)
    }
    
    // MARK: DELETE
    
    private func deleteRecipe() {
        
        isDeleting = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            
            do {
                
                try DatabaseManager.shared.deleteRecipe(id: recipeId)
                
                DispatchQueue.main.async {
                    isDeleting = false
                    dismiss()
                }
                
            } catch {
                
                DispatchQueue.main.async {
                    errorText = error.localizedDescription
                    isDeleting = false
                    showingDeleteAlert = false
                }
            }
        }
    }
    
    // MARK: - Load Data
    
    private func load() {
        print("🔄 Загрузка рецепта id: \(recipeId)")
        
        DispatchQueue.global(qos: .userInitiated).async {
            
            do {
                // Загружаем детали рецепта
                let detailData = try DatabaseManager.shared.fetchRecipeDetail(recipeId: recipeId)
                print("✅ Загружен рецепт: \(detailData.title)")
                
                // Загружаем ингредиенты
                let ingredientData = try DatabaseManager.shared.fetchIngredients(recipeId: recipeId)
                print("✅ Загружено ингредиентов: \(ingredientData.count)")
                
                // Выводим каждый ингредиент для отладки
                for ingredient in ingredientData {
                    print("   📝 id: \(ingredient.id), \(ingredient.name) - '\(ingredient.amountText)'")
                }
                
                DispatchQueue.main.async {
                    self.detail = detailData
                    self.ingredients = ingredientData
                }
                
            } catch {
                print("❌ Ошибка загрузки: \(error)")
                
                DispatchQueue.main.async {
                    self.errorText = error.localizedDescription
                }
            }
        }
    }
}

// MARK: HEADER

private extension RecipeDetailView {
    
    func header(_ detail: RecipeDetail) -> some View {
        
        VStack(spacing: 12) {
            
            Text(detail.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            
            Text(detail.metaLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            categoryCuisine(detail)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white.opacity(0.2))
        )
        .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
    }
    
    func categoryCuisine(_ detail: RecipeDetail) -> some View {
        
        HStack(spacing: 8) {
            
            Text(detail.categoryName)
                .font(.caption.bold())
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(.regularMaterial))
            
            if let cuisine = detail.cuisineName, !cuisine.isEmpty {
                Text(cuisine)
                    .font(.caption)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.regularMaterial))
            }
        }
    }
}

// MARK: NUTRITION

private extension RecipeDetailView {
    
    func nutritionInfo(_ detail: RecipeDetail) -> some View {
        
        VStack(alignment: .leading, spacing: 16) {
            
            sectionHeader("Пищевая ценность")
            
            if let calories = detail.calories {
                nutritionRow(
                    icon: "flame.fill",
                    iconColor: .orange,
                    title: "Калории",
                    value: "\(Int(calories)) ккал"
                )
            }
            
            HStack(spacing: 12) {
                
                if let protein = detail.protein {
                    nutritionCompactRow(
                        title: "Белки",
                        value: "\(Int(protein)) г",
                        color: .blue
                    )
                }
                
                if let fat = detail.fat {
                    nutritionCompactRow(
                        title: "Жиры",
                        value: "\(Int(fat)) г",
                        color: .green
                    )
                }
                
                if let carbs = detail.carbs {
                    nutritionCompactRow(
                        title: "Углеводы",
                        value: "\(Int(carbs)) г",
                        color: .purple
                    )
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white.opacity(0.2))
        )
        .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
    }
    
    func nutritionRow(icon: String, iconColor: Color, title: String, value: String) -> some View {
        
        HStack {
            
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 24)
            
            Text(title)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .bold()
        }
    }
    
    func nutritionCompactRow(title: String, value: String, color: Color) -> some View {
        
        VStack(spacing: 6) {
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
            
            RoundedRectangle(cornerRadius: 2)
                .fill(color.opacity(0.3))
                .frame(width: 30, height: 3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: INGREDIENTS

private extension RecipeDetailView {
    
    var ingredientsSection: some View {
        
        VStack(alignment: .leading, spacing: 14) {
            
            sectionHeader("Ингредиенты")
            
            if ingredients.isEmpty {
                Text("Ингредиенты не указаны")
                    .foregroundStyle(.secondary)
                    .italic()
                    .padding(.vertical, 8)
            } else {
                ForEach(ingredients) { ingredient in
                    
                    HStack(alignment: .center, spacing: 12) {
                        
                        // Маркер
                        Text("•")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                            .frame(width: 15)
                        
                        // Название ингредиента
                        Text(ingredient.name)
                            .font(.body)
                            .lineLimit(1)
                        
                        Spacer(minLength: 8)
                        
                        // Количество (всегда показываем, даже если пусто)
                        Text(ingredient.amountText.isEmpty ? "—" : ingredient.amountText)
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                            )
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white.opacity(0.2))
        )
        .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
    }
}

// MARK: INSTRUCTIONS

private extension RecipeDetailView {
    
    func instructionsSection(_ detail: RecipeDetail) -> some View {
        
        VStack(alignment: .leading, spacing: 14) {
            
            sectionHeader("Приготовление")
            
            if detail.instructions.isEmpty {
                Text("Инструкция отсутствует")
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                Text(formatSteps(detail.instructions))
                    .textSelection(.enabled)
                    .lineSpacing(6)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white.opacity(0.2))
        )
        .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
    }
    
    func formatSteps(_ text: String) -> String {
        
        let steps = text
            .components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        if steps.count > 1 {
            return steps.enumerated()
                .map { "\($0 + 1). \($1)" }
                .joined(separator: "\n\n")
        }
        
        return text
    }
}

// MARK: HELPERS

private extension RecipeDetailView {
    
    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title3.bold())
    }
    
    var loadingView: some View {
        
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Загрузка рецепта...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    func errorView(_ text: String) -> some View {
        
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.red)
            
            Text(text)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        RecipeDetailView(recipeId: 1)
    }
}
