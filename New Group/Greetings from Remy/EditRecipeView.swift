import SwiftUI

struct EditRecipeView: View {

    let recipeId: Int
    let recipe: RecipeDetail
    let ingredients: [IngredientLine]
    var onSaved: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var categories: [CategoryRow] = []
    @State private var cuisines: [CuisineRow] = []
    @State private var errorText: String?
    @State private var isSaving = false

    // Поля для редактирования
    @State private var title: String = ""
    @State private var categoryId: Int = 0
    @State private var selectedCuisineId: Int? = nil
    @State private var difficulty: String = "medium"
    @State private var timeMinutes: String = ""
    @State private var servings: String = ""
    @State private var instructions: String = ""
    @State private var ingredientsText: String = ""
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var fat: String = ""
    @State private var carbs: String = ""

    var body: some View {

        NavigationStack {

            ZStack {

                AppBackground(.list)

                ScrollView {

                    VStack(spacing: 16) {

                        if let errorText {
                            messageView(text: errorText, color: .red)
                        }

                        if isSaving {
                            ProgressView()
                                .padding(.top, 40)
                        }

                        editForm
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Редактировать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {

                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saveChanges()
                    }
                    .disabled(isSaving || title.isEmpty)
                }
            }
            .onAppear {
                loadData()
            }
        }
    }

    // MARK: - Edit Form

    private var editForm: some View {
        VStack(alignment: .leading, spacing: 18) {

            // Основное
            Group {
                Text("Основное")
                    .font(.headline)

                TextField("Название", text: $title)
                    .textFieldStyle(.roundedBorder)

                // Категория
                Menu {
                    ForEach(categories) { category in
                        Button(category.name) {
                            categoryId = category.id
                        }
                    }
                } label: {
                    HStack {
                        Text("Категория")
                        Spacer()
                        Text(categories.first(where: { $0.id == categoryId })?.name ?? "Выберите")
                            .foregroundStyle(.secondary)
                    }
                }

                // Кухня
                Menu {
                    Button("Без кухни") {
                        selectedCuisineId = nil
                    }
                    Divider()
                    ForEach(cuisines) { cuisine in
                        Button(cuisine.name) {
                            selectedCuisineId = cuisine.id
                        }
                    }
                } label: {
                    HStack {
                        Text("Кухня")
                        Spacer()
                        Text(selectedCuisineName)
                            .foregroundStyle(.secondary)
                    }
                }

                // Сложность
                Picker("Сложность", selection: $difficulty) {
                    Text("Легко").tag("easy")
                    Text("Средне").tag("medium")
                    Text("Сложно").tag("hard")
                }
                .pickerStyle(.segmented)

                // Время и порции
                HStack {
                    TextField("Минуты", text: $timeMinutes)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)

                    TextField("Порции", text: $servings)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Divider()

            // Пищевая ценность
            Group {
                Text("Пищевая ценность (на 100г)")
                    .font(.headline)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    Text("Ккал").font(.caption).foregroundStyle(.secondary)
                    Text("Белки").font(.caption).foregroundStyle(.secondary)
                    Text("Жиры").font(.caption).foregroundStyle(.secondary)
                    Text("Угл.").font(.caption).foregroundStyle(.secondary)

                    TextField("0", text: $calories)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)

                    TextField("0", text: $protein)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)

                    TextField("0", text: $fat)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)

                    TextField("0", text: $carbs)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                }
            }

            Divider()

            // Ингредиенты
            Group {
                Text("Ингредиенты")
                    .font(.headline)

                Text("Каждый ингредиент с новой строки. Формат: Название — количество")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $ingredientsText)
                    .frame(minHeight: 150)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.regularMaterial)
                    )
            }

            Divider()

            // Инструкция
            Group {
                Text("Приготовление")
                    .font(.headline)

                TextEditor(text: $instructions)
                    .frame(minHeight: 200)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.regularMaterial)
                    )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.regularMaterial)
        )
    }

    // MARK: - Computed Properties

    private var selectedCuisineName: String {
        if let id = selectedCuisineId,
           let cuisine = cuisines.first(where: { $0.id == id }) {
            return cuisine.name
        }
        return "Не выбрана"
    }

    // MARK: - Load Data

    private func loadData() {
        do {
            // Загружаем категории и кухни
            let allCategories = try DatabaseManager.shared.fetchCategories()
            let allCuisines = try DatabaseManager.shared.fetchAllCuisines()

            // Заполняем поля из переданных данных
            title = recipe.title
            // Находим ID категории по имени
            if let category = allCategories.first(where: { $0.name == recipe.categoryName }) {
                categoryId = category.id
            }
            difficulty = recipe.difficulty
            timeMinutes = String(recipe.timeMinutes)
            servings = recipe.servingsText ?? ""
            instructions = recipe.instructions

            // Пищевая ценность
            calories = recipe.calories.map { String($0) } ?? ""
            protein = recipe.protein.map { String($0) } ?? ""
            fat = recipe.fat.map { String($0) } ?? ""
            carbs = recipe.carbs.map { String($0) } ?? ""

            // Ингредиенты в текст
            ingredientsText = ingredients.map { ingredient in
                if ingredient.amountText.isEmpty {
                    return ingredient.name
                } else {
                    return "\(ingredient.name) — \(ingredient.amountText)"
                }
            }.joined(separator: "\n")

            // Кухня
            if let cuisineName = recipe.cuisineName,
               let cuisine = allCuisines.first(where: { $0.name == cuisineName }) {
                selectedCuisineId = cuisine.id
            }

            categories = allCategories
            cuisines = allCuisines

        } catch {
            errorText = error.localizedDescription
        }
    }

    // MARK: - Save Changes

    private func saveChanges() {
        isSaving = true
        errorText = nil

        let ingredientLines = ingredientsText
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        let timeMinutesValue = Int(timeMinutes) ?? 0
        let caloriesValue = Double(calories.replacingOccurrences(of: ",", with: "."))
        let proteinValue = Double(protein.replacingOccurrences(of: ",", with: "."))
        let fatValue = Double(fat.replacingOccurrences(of: ",", with: "."))
        let carbsValue = Double(carbs.replacingOccurrences(of: ",", with: "."))

        let cuisineName = selectedCuisineId.flatMap { id in
            cuisines.first(where: { $0.id == id })?.name
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try DatabaseManager.shared.updateRecipe(
                    recipeId: recipeId,
                    title: title,
                    categoryId: categoryId,
                    cuisineName: cuisineName,
                    difficulty: difficulty,
                    timeMinutes: timeMinutesValue,
                    servingsText: servings.isEmpty ? nil : servings,
                    instructions: instructions,
                    ingredientsLines: ingredientLines,
                    calories: caloriesValue,
                    protein: proteinValue,
                    fat: fatValue,
                    carbs: carbsValue
                )

                DispatchQueue.main.async {
                    isSaving = false
                    onSaved?()
                    dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    errorText = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }

    // MARK: - Message View

    private func messageView(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(color)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
            .cornerRadius(8)
    }
}

#Preview {
    let sampleRecipe = RecipeDetail(
        id: 1,
        title: "Тестовый рецепт",
        categoryName: "Салаты",
        cuisineName: "Итальянская",
        difficulty: "medium",
        timeMinutes: 30,
        timeText: "30 мин",
        servingsText: "4 порции",
        instructions: "1. Смешать ингредиенты\n2. Подавать",
        calories: 250,
        protein: 10,
        fat: 15,
        carbs: 20
    )
    
    let sampleIngredients = [
        IngredientLine(id: 1, name: "Помидоры", amountText: "2 шт", sortOrder: 0),
        IngredientLine(id: 2, name: "Огурцы", amountText: "1 шт", sortOrder: 1)
    ]
    
    return EditRecipeView(
        recipeId: 1,
        recipe: sampleRecipe,
        ingredients: sampleIngredients
    )
}
