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
                        
                        // Кнопка удаления
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
            Button("Отмена", role: .cancel) { }
            Button("Удалить", role: .destructive) {
                deleteRecipe()
            }
        } message: {
            Text("Вы уверены, что хотите удалить рецепт «\(detail?.title ?? "")»?")
        }
        .onAppear { load() }
    }
    
    // MARK: - Delete Button
    
    private var deleteButton: some View {
        Button(action: {
            showingDeleteAlert = true
        }) {
            HStack {
                if isDeleting {
                    ProgressView()
                        .tint(.red)
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
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(isDeleting)
    }
    
    // MARK: - Delete Function
    
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
}

// MARK: HEADER

private extension RecipeDetailView {
    
    func header(_ detail: RecipeDetail) -> some View {
        
        VStack(alignment: .center, spacing: 12) {
            
            Text(detail.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
            
            Text(detail.metaLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            
            categoryCuisine(detail)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .opacity(0.8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(
            color: .black.opacity(0.1),
            radius: 15,
            x: 0,
            y: 8
        )
    }
    
    func categoryCuisine(_ detail: RecipeDetail) -> some View {
        
        HStack(spacing: 8) {
            
            Text(detail.categoryName)
                .font(.caption.bold())
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(.regularMaterial)
                        .opacity(0.9)
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .lineLimit(1)
            
            if let cuisine = detail.cuisineName,
               !cuisine.isEmpty {
                
                Text(cuisine)
                    .font(.caption)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.regularMaterial)
                            .opacity(0.9)
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: NUTRITION INFO

private extension RecipeDetailView {
    
    func nutritionInfo(_ detail: RecipeDetail) -> some View {
        
        VStack(alignment: .leading, spacing: 16) {
            
            sectionHeader("Пищевая ценность")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)
            
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .opacity(0.8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(
            color: .black.opacity(0.1),
            radius: 15,
            x: 0,
            y: 8
        )
    }
    
    func nutritionRow(icon: String, iconColor: Color, title: String, value: String) -> some View {
        
        HStack(spacing: 12) {
            
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .font(.system(size: 16))
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }
    
    func nutritionCompactRow(title: String, value: String, color: Color) -> some View {
        
        VStack(alignment: .center, spacing: 6) {
            
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
                .opacity(0.7)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: INGREDIENTS

private extension RecipeDetailView {
    
    var ingredientsSection: some View {
        
        VStack(alignment: .leading, spacing: 14) {
            
            sectionHeader("Ингредиенты")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 2)
            
            ForEach(ingredients) { ingredient in
                
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    
                    Text("•")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                        .frame(width: 15)
                    
                    Text(ingredient.name)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer(minLength: 8)
                    
                    Text(ingredient.amountText)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .opacity(0.5)
                        )
                }
                .padding(.vertical, 4)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .opacity(0.8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(
            color: .black.opacity(0.1),
            radius: 15,
            x: 0,
            y: 8
        )
    }
}

// MARK: INSTRUCTIONS

private extension RecipeDetailView {
    
    func instructionsSection(_ detail: RecipeDetail) -> some View {
        
        VStack(alignment: .leading, spacing: 14) {
            
            sectionHeader("Приготовление")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 2)
            
            Text(formatSteps(detail.instructions))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineSpacing(6)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .opacity(0.8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(
            color: .black.opacity(0.1),
            radius: 15,
            x: 0,
            y: 8
        )
    }
    
    func formatSteps(_ text: String) -> String {
        
        let steps = text
            .components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        if steps.count > 1 {
            
            return steps.enumerated()
                .map { "\($0+1). \($1)" }
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
            .foregroundStyle(.primary)
    }
    
    var loadingView: some View {
        
        ProgressView()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
                    .opacity(0.8)
            )
            .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
            .padding(.horizontal, 4)
    }
    
    func errorView(_ text: String) -> some View {
        
        Text(text)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
                    .opacity(0.8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
            .padding(.horizontal, 4)
    }
    
    func load() {
        do {
            detail = try DatabaseManager.shared.fetchRecipeDetail(recipeId: recipeId)
            ingredients = try DatabaseManager.shared.fetchIngredients(recipeId: recipeId)
        } catch {
            errorText = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        RecipeDetailView(recipeId: 1)
    }
}
