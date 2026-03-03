import SwiftUI

struct EditRecipeView: View {
    
    let recipeId: Int
    var onSaved: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var categories: [CategoryRow] = []
    @State private var selectedCategoryId: Int = 0
    
    @State private var title = ""
    @State private var cuisine = ""
    @State private var difficultyCode = "medium"
    @State private var timeMinutesText = ""
    @State private var timeText = ""
    @State private var servings = ""
    @State private var ingredientsText = ""
    @State private var instructions = ""
    
    @State private var errorText: String?
    
    var body: some View {
        NavigationStack {
            Form {
                
                Section("Основное") {
                    
                    TextField("Название", text: $title)
                    
                    Picker("Категория", selection: $selectedCategoryId) {
                        ForEach(categories) { category in
                            Text(category.name).tag(category.id)
                        }
                    }
                    
                    TextField("Кухня", text: $cuisine)
                    
                    Picker("Сложность", selection: $difficultyCode) {
                        Text("легко").tag("easy")
                        Text("средне").tag("medium")
                        Text("сложно").tag("hard")
                    }
                    
                    TextField("Минуты", text: $timeMinutesText)
                        .keyboardType(.numberPad)
                    
                    TextField("Текст времени", text: $timeText)
                    
                    TextField("Порции", text: $servings)
                }
                
                Section("Ингредиенты") {
                    TextEditor(text: $ingredientsText)
                        .frame(minHeight: 120)
                }
                
                Section("Шаги") {
                    TextEditor(text: $instructions)
                        .frame(minHeight: 150)
                }
                
                if let errorText {
                    Section {
                        Text(errorText)
                            .foregroundStyle(.red)
                    }
                }
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
        }
    }
    
    // MARK: - Load
    
    private func loadAll() {
        do {
            categories = try DatabaseManager.shared.fetchCategories()
            
            let detail = try DatabaseManager.shared.fetchRecipeDetail(recipeId: recipeId)
            let ingredients = try DatabaseManager.shared.fetchIngredients(recipeId: recipeId)
            
            title = detail.title
            cuisine = detail.cuisineName ?? ""
            difficultyCode = detail.difficulty
            timeMinutesText = detail.timeMinutes > 0 ? "\(detail.timeMinutes)" : ""
            timeText = detail.timeText
            servings = detail.servingsText ?? ""
            instructions = detail.instructions
            
            if let category = categories.first(where: { $0.name == detail.categoryName }) {
                selectedCategoryId = category.id
            }
            
            ingredientsText = ingredients
                .map { "\($0.name) — \($0.amountText)" }
                .joined(separator: "\n")
            
        } catch {
            errorText = error.localizedDescription
        }
    }
    
    // MARK: - Save
    
    private func save() {
        do {
            let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanTitle.isEmpty else {
                errorText = "Название не может быть пустым"
                return
            }
            
            let minutes = Int(timeMinutesText) ?? 0
            
            let lines = ingredientsText
                .split(separator: "\n")
                .map { String($0) }
            
        } catch {
            errorText = error.localizedDescription
        }
    }
}
