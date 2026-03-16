import SwiftUI

// MARK: - Тип добавляемого объекта

enum AddableType: String, CaseIterable, Identifiable {
    
    case recipe = "Рецепт"
    case category = "Категория"
    case cuisine = "Кухня"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .recipe: return "mouse_pen"
        case .category: return "mouse_book"
        case .cuisine: return "mouse_world"
        }
    }
    
    var title: String {
        switch self {
        case .recipe: return "новый рецепт"
        case .category: return "новую категорию"
        case .cuisine: return "новую кухню"
        }
    }
    
    var iconSize: CGFloat {
        switch self {
        case .recipe: return 90
        case .category: return 135
        case .cuisine: return 145
        }
    }
}

struct AddRecipeView: View {
    
    // MARK: Data
    
    @State private var categories: [CategoryRow] = []
    @State private var cuisines: [CuisineRow] = []
    
    @State private var selectedCategoryId: Int = -1
    @State private var selectedCuisineId: Int? = nil
    
    @State private var addableType: AddableType = .recipe
    
    // MARK: Общие поля
    
    @State private var name = ""
    
    // MARK: Поля рецепта
    
    @State private var title = ""
    @State private var timeText = ""
    @State private var servings = ""
    @State private var difficulty = "medium"
    
    @State private var ingredientsText = ""
    @State private var instructions = ""
    
    @State private var calories = ""
    @State private var protein = ""
    @State private var fat = ""
    @State private var carbs = ""
    
    // MARK: UI
    
    @State private var errorText: String?
    @State private var successText: String?
    @State private var isSaving = false
    @State private var showingDeleteManagement = false
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: Body
    
    var body: some View {
        
        NavigationStack {
            
            ZStack {
                
                AppBackground(.list)
                
                ScrollView {
                    
                    VStack(spacing: 18) {
                        
                        headerView
                        
                        typePicker
                        
                        if let errorText {
                            messageView(text: errorText, color: .red)
                        }
                        
                        if let successText {
                            messageView(text: successText, color: .green)
                        }
                        
                        formCard
                        
                        if addableType == .category || addableType == .cuisine {
                            deleteButton
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            
            .toolbar {
                
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "..." : "Сохранить") {
                        save()
                    }
                    .disabled(isSaving || !isFormValid)
                }
            }
            
            .sheet(isPresented: $showingDeleteManagement) {
                DeleteManagementView()
            }
            
            .onAppear {
                loadCategories()
                loadCuisines()
            }
        }
    }
}

////////////////////////////////////////////////////////////
/// MARK: UI Blocks
////////////////////////////////////////////////////////////

extension AddRecipeView {
    
    private var headerView: some View {
        
        HStack(spacing: 18) {
            
            Image(addableType.icon)
                .resizable()
                .scaledToFit()
                .frame(width: addableType.iconSize,
                       height: addableType.iconSize)
            
            VStack(alignment: .leading, spacing: 4) {
                
                Text("Добавить")
                    .font(.title.bold())
                
                Text(addableType.title)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 10)
    }
    
    private var typePicker: some View {
        
        Picker("Тип", selection: $addableType) {
            ForEach(AddableType.allCases) { type in
                Text(type.rawValue).tag(type)
            }
        }
        .pickerStyle(.segmented)
    }
    
    @ViewBuilder
    private var formCard: some View {
        
        switch addableType {
        case .recipe:
            recipeForm
            
        case .category, .cuisine:
            simpleForm
        }
    }
    
    private var simpleForm: some View {
        
        VStack(alignment: .leading, spacing: 14) {
            
            Text("Название")
                .font(.headline)
            
            TextField("Введите название", text: $name)
                .textFieldStyle(.roundedBorder)
        }
        .padding(18)
        .glassCard()
    }
}

////////////////////////////////////////////////////////////
/// MARK: Recipe Form
////////////////////////////////////////////////////////////

extension AddRecipeView {
    
    private var recipeForm: some View {
        
        VStack(alignment: .leading, spacing: 16) {
            
            Text("Основное")
                .font(.headline)
            
            TextField("Название", text: $title)
                .textFieldStyle(.roundedBorder)
            
            categoryMenu
            
            cuisineMenu
            
            Picker("Сложность", selection: $difficulty) {
                Text("легко").tag("easy")
                Text("средне").tag("medium")
                Text("сложно").tag("hard")
            }
            .pickerStyle(.segmented)
            
            HStack {
                
                TextField("Минуты", text: $timeText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Порции", text: $servings)
                    .textFieldStyle(.roundedBorder)
            }
            
            Divider()
            
            Text("Ингредиенты")
                .font(.headline)
            
            TextEditor(text: $ingredientsText)
                .frame(minHeight: 120)
                .padding(6)
                .background(.regularMaterial)
                .cornerRadius(8)
            
            Divider()
            
            Text("Шаги")
                .font(.headline)
            
            TextEditor(text: $instructions)
                .frame(minHeight: 120)
                .padding(6)
                .background(.regularMaterial)
                .cornerRadius(8)
        }
        .padding(18)
        .glassCard()
    }
}

////////////////////////////////////////////////////////////
/// MARK: Menus
////////////////////////////////////////////////////////////

extension AddRecipeView {
    
    private var categoryMenu: some View {
        
        Menu {
            
            ForEach(categories) { category in
                Button(category.name) {
                    selectedCategoryId = category.id
                }
            }
            
        } label: {
            
            HStack {
                
                Text("Категория")
                
                Spacer()
                
                Text(selectedCategoryName)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var cuisineMenu: some View {
        
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
    }
    
    private var selectedCategoryName: String {
        categories.first(where: { $0.id == selectedCategoryId })?.name ?? "Выберите"
    }
    
    private var selectedCuisineName: String {
        if let id = selectedCuisineId,
           let cuisine = cuisines.first(where: { $0.id == id }) {
            return cuisine.name
        }
        return "Не выбрана"
    }
}

////////////////////////////////////////////////////////////
/// MARK: Buttons
////////////////////////////////////////////////////////////

extension AddRecipeView {
    
    private var deleteButton: some View {
        
        Button {
            showingDeleteManagement = true
        } label: {
            
            HStack {
                Image(systemName: "trash")
                Text("Управление удалением")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.regularMaterial)
            .cornerRadius(12)
        }
    }
}

////////////////////////////////////////////////////////////
/// MARK: Validation
////////////////////////////////////////////////////////////

extension AddRecipeView {
    
    private var isFormValid: Bool {
        
        switch addableType {
            
        case .recipe:
            return !title.trimmingCharacters(in: .whitespaces).isEmpty &&
                   selectedCategoryId != -1 &&
                   !instructions.trimmingCharacters(in: .whitespaces).isEmpty
            
        case .category, .cuisine:
            return !name.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }
}

////////////////////////////////////////////////////////////
/// MARK: Message
////////////////////////////////////////////////////////////

extension AddRecipeView {
    
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
// MARK: - Data Loading

extension AddRecipeView {

    private func loadCategories() {
        do {
            categories = try DatabaseManager.shared.fetchCategories()

            if selectedCategoryId == -1 {
                selectedCategoryId = categories.first?.id ?? -1
            }
        } catch {
            errorText = "Ошибка загрузки категорий: \(error.localizedDescription)"
        }
    }

    private func loadCuisines() {
        do {
            cuisines = try DatabaseManager.shared.fetchAllCuisines()
        } catch {
            errorText = "Ошибка загрузки кухонь: \(error.localizedDescription)"
        }
    }
}

////////////////////////////////////////////////////////////
/// MARK: Save Logic
////////////////////////////////////////////////////////////

extension AddRecipeView {

    private func save() {

        errorText = nil
        successText = nil
        isSaving = true

        DispatchQueue.global(qos: .userInitiated).async {

            do {

                switch addableType {

                case .recipe:
                    try saveRecipe()

                case .category:
                    try saveCategory()

                case .cuisine:
                    try saveCuisine()
                }

                DispatchQueue.main.async {

                    successText = "Успешно сохранено!"
                    isSaving = false

                    clearForm()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }

            } catch {

                DispatchQueue.main.async {
                    errorText = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }

    private func saveRecipe() throws {

        let ingredientLines = ingredientsText
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        let cuisineName = selectedCuisineId.flatMap { id in
            cuisines.first(where: { $0.id == id })?.name
        }

        try DatabaseManager.shared.addRecipe(
            title: title,
            categoryId: selectedCategoryId,
            cuisineName: cuisineName,
            difficulty: difficulty,
            timeMinutes: Int(timeText) ?? 0,
            servingsText: servings.isEmpty ? nil : servings,
            instructions: instructions,
            ingredientsLines: ingredientLines,
            calories: Double(calories),
            protein: Double(protein),
            fat: Double(fat),
            carbs: Double(carbs)
        )
    }

    private func saveCategory() throws {
        try DatabaseManager.shared.addCategory(name: name)
    }

    private func saveCuisine() throws {
        try DatabaseManager.shared.addCuisine(name: name)
    }

    private func clearForm() {

        name = ""
        title = ""
        timeText = ""
        servings = ""
        ingredientsText = ""
        instructions = ""

        calories = ""
        protein = ""
        fat = ""
        carbs = ""
    }
}
////////////////////////////////////////////////////////////
/// MARK: Preview
////////////////////////////////////////////////////////////

struct AddRecipeView_Previews: PreviewProvider {
    static var previews: some View {
        AddRecipeView()
    }
}
