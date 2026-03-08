import SwiftUI

// MARK: - Модели для добавления

enum AddableType: String, CaseIterable {
    case recipe = "Рецепт"
    case category = "Категория"
    case cuisine = "Кухня"
    
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
    
    // MARK: - Data
    
    @State private var categories: [CategoryRow] = []
    @State private var cuisines: [CuisineRow] = []
    @State private var selectedCategoryId: Int = -1
    @State private var selectedCuisineId: Int? = nil
    @State private var addableType: AddableType = .recipe
    
    // MARK: - Fields (общие)
    @State private var name = ""
    
    // MARK: - Fields (для рецепта)
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
    
    // MARK: - UI State
    @State private var errorText: String?
    @State private var successText: String?
    @State private var isSaving = false
    @State private var showingDeleteManagement = false // Добавлено
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground(.list)
                
                ScrollView {
                    VStack(spacing: 16) {
                        header
                        typePicker
                        
                        if let errorText {
                            messageView(text: errorText, color: .red)
                        }
                        
                        if let successText {
                            messageView(text: successText, color: .green)
                        }
                        
                        formCard
                        
                        // Кнопка управления удалением внизу
                        if addableType == .category || addableType == .cuisine {
                            deleteManagementButton
                                .padding(.top, 20)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("")
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
    
    // MARK: - Delete Management Button
    
    private var deleteManagementButton: some View {
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
            .foregroundColor(.red)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Type Picker
    
    private var typePicker: some View {
        Picker("Тип", selection: $addableType) {
            ForEach(AddableType.allCases, id: \.self) { type in
                Text(type.rawValue).tag(type)
            }
        }
        .pickerStyle(.segmented)
        .padding(.top, 8)
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: 20) {
            Image(addableType.icon)
                .resizable()
                .scaledToFit()
                .frame(width: addableType.iconSize, height: addableType.iconSize)
                .background(
                    Circle()
                        .fill(.regularMaterial)
                        .frame(width: addableType.iconSize + 10,
                               height: addableType.iconSize + 10)
                )
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Добавить")
                    .font(.title.bold())
                
                Text(addableType.title)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
    }
    
    // MARK: - Form Valid
    
    private var isFormValid: Bool {
        switch addableType {
        case .recipe:
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            selectedCategoryId != -1 &&
            !instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .category, .cuisine:
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    // MARK: - Form Card
    
    @ViewBuilder
    private var formCard: some View {
        switch addableType {
        case .recipe:
            recipeForm
        case .category, .cuisine:
            simpleForm
        }
    }
    
    // MARK: - Simple Form
    
    private var simpleForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Название")
                .font(.headline)
            
            TextField("Введите название", text: $name)
                .textFieldStyle(.roundedBorder)
        }
        .padding(18)
        .glassCard()
    }
    
    // MARK: - Recipe Form
    
    private var recipeForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            
            // MARK: Основное
            Text("Основное")
                .font(.headline)
            
            TextField("Название", text: $title)
                .textFieldStyle(.roundedBorder)
            
            // Категория
            categoryMenu
            
            // Кухня
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
            
            // MARK: - Пищевая ценность
            Text("Пищевая ценность (на 100г)")
                .font(.headline)
                .padding(.top, 8)
            
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
            .padding(.bottom, 8)
            
            Divider()
            
            // MARK: Ингредиенты
            Text("Ингредиенты")
                .font(.headline)
            
            Text("Каждый ингредиент с новой строки. Формат: Название — количество")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            TextEditor(text: $ingredientsText)
                .frame(minHeight: 100)
                .padding(6)
                .background(.regularMaterial)
                .cornerRadius(8)
            
            Divider()
            
            // MARK: Шаги
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
    
    // MARK: - Cuisine Menu
    
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
    
    private var selectedCuisineName: String {
        if let id = selectedCuisineId,
           let cuisine = cuisines.first(where: { $0.id == id }) {
            return cuisine.name
        }
        return "Не выбрана"
    }
    
    // MARK: - Category Menu
    
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
    
    private var selectedCategoryName: String {
        categories.first(where: { $0.id == selectedCategoryId })?.name ?? "Выберите"
    }
    
    // MARK: - Load Data
    
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
    
    // MARK: - Save
    
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
                    
                    switch addableType {
                    case .recipe:
                        clearRecipeForm()
                    case .category, .cuisine:
                        name = ""
                    }
                    
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
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanTitle.isEmpty else {
            throw NSError(domain: "", code: 1, userInfo: [NSLocalizedDescriptionKey: "Добавь название"])
        }
        
        guard selectedCategoryId != -1 else {
            throw NSError(domain: "", code: 2, userInfo: [NSLocalizedDescriptionKey: "Выбери категорию"])
        }
        
        guard !instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "", code: 3, userInfo: [NSLocalizedDescriptionKey: "Добавь шаги приготовления"])
        }
        
        let ingredientLines = ingredientsText
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        let timeMinutes = Int(timeText) ?? 0
        
        let caloriesValue = Double(calories.replacingOccurrences(of: ",", with: "."))
        let proteinValue = Double(protein.replacingOccurrences(of: ",", with: "."))
        let fatValue = Double(fat.replacingOccurrences(of: ",", with: "."))
        let carbsValue = Double(carbs.replacingOccurrences(of: ",", with: "."))
        
        // Получаем название кухни если выбрана
        let cuisineName = selectedCuisineId.flatMap { id in
            cuisines.first(where: { $0.id == id })?.name
        }
        
        try DatabaseManager.shared.addRecipe(
            title: cleanTitle,
            categoryId: selectedCategoryId,
            cuisineName: cuisineName,
            difficulty: difficulty,
            timeMinutes: timeMinutes,
            servingsText: servings.isEmpty ? nil : servings,
            instructions: instructions,
            ingredientsLines: ingredientLines,
            calories: caloriesValue,
            protein: proteinValue,
            fat: fatValue,
            carbs: carbsValue
        )
    }
    
    private func saveCategory() throws {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanName.isEmpty else {
            throw NSError(domain: "", code: 4, userInfo: [NSLocalizedDescriptionKey: "Введите название категории"])
        }
        
        let _ = try DatabaseManager.shared.addCategory(name: cleanName)
    }
    
    private func saveCuisine() throws {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanName.isEmpty else {
            throw NSError(domain: "", code: 5, userInfo: [NSLocalizedDescriptionKey: "Введите название кухни"])
        }
        
        let _ = try DatabaseManager.shared.addCuisine(name: cleanName)
    }
    
    private func clearRecipeForm() {
        title = ""
        timeText = ""
        servings = ""
        ingredientsText = ""
        instructions = ""
        calories = ""
        protein = ""
        fat = ""
        carbs = ""
        selectedCategoryId = categories.first?.id ?? -1
        selectedCuisineId = nil
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
    AddRecipeView()
}
