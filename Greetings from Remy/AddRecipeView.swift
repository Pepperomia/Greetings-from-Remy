import SwiftUI

struct AddRecipeView: View {
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Data
    
    @State private var categories: [CategoryRow] = []
    @State private var cuisines: [CuisineRow] = []
    @State private var selectedCategoryId: Int = -1
    @State private var selectedCuisineId: Int? = nil
    
    // MARK: - Fields
    
    @State private var title = ""
    @State private var timeText = ""
    @State private var servings = ""
    @State private var difficulty = "medium"
    @State private var ingredientsText = ""
    @State private var instructions = ""
    
    // MARK: - UI State
    
    @State private var errorText: String?
    @State private var successText: String?
    @State private var showAddCuisine = false
    @State private var isSaving = false
    
    // MARK: - Constants
    
    private enum Constants {
        static let headerMouseSize: CGFloat = 100
        static let headerSidePadding: CGFloat = 20
        static let headerTopPadding: CGFloat = 10
        
        static let glassCorner: CGFloat = 16
        static let glassStrokeOpacity: Double = 0.18
        static let glassVPad: CGFloat = 12
        static let glassHPad: CGFloat = 16
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground(.list)
                
                ScrollView {
                    VStack(spacing: 16) {
                        headerRow
                        
                        if let errorText = errorText {
                            errorView(errorText)
                        }
                        
                        if let successText = successText {
                            successView(successText)
                        }
                        
                        mainCard
                    }
                    .padding(.horizontal, Constants.headerSidePadding)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    saveButton
                }
            }
            .sheet(isPresented: $showAddCuisine) {
                AddCuisineSheet {
                    loadCuisines()
                }
            }
            .onAppear {
                loadCategories()
                loadCuisines()
            }
        }
    }
    
    // MARK: - Header
    
    private var headerRow: some View {
        HStack(spacing: 16) {
            MouseSticker(name: "mouse_pen", size: Constants.headerMouseSize)
                .background(
                    Circle()
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Добавить")
                    .font(.title.bold())
                    .foregroundStyle(.primary)
                
                Text("новый рецепт")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, Constants.headerSidePadding)
        .padding(.top, Constants.headerTopPadding)
    }
    
    // MARK: - Main Card
    
    private var mainCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Основное
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader("Основное")
                
                VStack(spacing: 16) {
                    // Название
                    TextField("Название рецепта", text: $title)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.regularMaterial)
                        .cornerRadius(8)
                    
                    // Категория
                    categoryPicker
                    
                    // Кухня
                    cuisinePicker
                    
                    // Сложность
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Сложность")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Picker("Сложность", selection: $difficulty) {
                            Text("легко").tag("easy")
                            Text("средне").tag("medium")
                            Text("сложно").tag("hard")
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Время и порции
                    HStack(spacing: 12) {
                        TextField("Время (мин)", text: $timeText)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(.regularMaterial)
                            .cornerRadius(8)
                            .keyboardType(.numberPad)
                        
                        TextField("Порции", text: $servings)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(.regularMaterial)
                            .cornerRadius(8)
                    }
                }
            }
            
            Divider()
                .background(.secondary.opacity(0.3))
            
            // Ингредиенты
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader("Ингредиенты")
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Каждая строка: Ингредиент — Количество")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextEditor(text: $ingredientsText)
                        .frame(minHeight: 120)
                        .padding(4)
                        .background(.regularMaterial)
                        .cornerRadius(8)
                }
            }
            
            Divider()
                .background(.secondary.opacity(0.3))
            
            // Шаги
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader("Шаги приготовления")
                
                TextEditor(text: $instructions)
                    .frame(minHeight: 160)
                    .padding(4)
                    .background(.regularMaterial)
                    .cornerRadius(8)
            }
        }
        .padding(20)
        .glassCard()
    }
    
    // MARK: - Pickers
    
    private var categoryPicker: some View {
        Menu {
            ForEach(categories) { category in
                Button(category.name) {
                    selectedCategoryId = category.id
                }
            }
        } label: {
            HStack {
                Text("Категория")
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text(selectedCategoryName)
                    .foregroundStyle(.secondary)
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    private var cuisinePicker: some View {
        HStack {
            Menu {
                Button("Не выбрано") { selectedCuisineId = nil }
                Divider()
                ForEach(cuisines) { cuisine in
                    Button(cuisine.name) { selectedCuisineId = cuisine.id }
                }
                Divider()
                Button("➕ Добавить кухню") {
                    showAddCuisine = true
                }
            } label: {
                HStack {
                    Text("Кухня мира")
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text(selectedCuisineName)
                        .foregroundStyle(.secondary)
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.regularMaterial)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
    }
    
    private func errorView(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.red)
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func successView(_ message: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(message)
                .font(.caption)
                .foregroundStyle(.green)
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Buttons
    
    private var saveButton: some View {
        Button(action: save) {
            if isSaving {
                ProgressView()
                    .tint(.primary)
            } else {
                Text("Сохранить")
                    .bold()
            }
        }
        .disabled(isSaving)
    }
    
    // MARK: - Computed Properties
    
    private var selectedCategoryName: String {
        categories.first(where: { $0.id == selectedCategoryId })?.name ?? "Выберите"
    }
    
    private var selectedCuisineName: String {
        guard let id = selectedCuisineId else { return "Не выбрано" }
        return cuisines.first(where: { $0.id == id })?.name ?? "Не выбрано"
    }
    
    // MARK: - Load Data
    
    private func loadCategories() {
        do {
            categories = try DatabaseManager.shared.fetchCategories()
            if selectedCategoryId == -1, let first = categories.first {
                selectedCategoryId = first.id
            }
        } catch {
            errorText = error.localizedDescription
        }
    }
    
    private func loadCuisines() {
        do {
            cuisines = try DatabaseManager.shared.fetchAllCuisines()
                .map { cuisine in
                    let trimmed = cuisine.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let pretty = trimmed.prefix(1).uppercased() + trimmed.dropFirst().lowercased()
                    return CuisineRow(id: cuisine.id, name: pretty)
                }
                .sorted { $0.name < $1.name }
                .reduce(into: [String: CuisineRow]()) { dict, cuisine in
                    let key = cuisine.name.lowercased()
                    if dict[key] == nil {
                        dict[key] = cuisine
                    }
                }
                .values
                .sorted { $0.name < $1.name }
        } catch {
            errorText = "Ошибка загрузки кухонь: \(error.localizedDescription)"
            cuisines = []
        }
    }
    
    // MARK: - Save Action
    
    private func save() {
        isSaving = true
        errorText = nil
        successText = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleanTitle.isEmpty {
                    throw NSError(domain: "Validation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Добавь название"])
                }
                
                let timeMinutes = Int(timeText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                
                let lines = ingredientsText
                    .split(separator: "\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                let cleanInstructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleanInstructions.isEmpty {
                    throw NSError(domain: "Validation", code: 2, userInfo: [NSLocalizedDescriptionKey: "Добавь шаги приготовления"])
                }
                
                let cuisineName = selectedCuisineId
                    .flatMap { id in cuisines.first { $0.id == id } }
                    .map { $0.name }
                
                try DatabaseManager.shared.addRecipe(
                    title: cleanTitle,
                    categoryId: selectedCategoryId,
                    cuisineName: cuisineName,
                    difficulty: difficulty,
                    timeMinutes: timeMinutes,
                    servingsText: servings.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : servings,
                    instructions: cleanInstructions,
                    ingredientsLines: lines
                )
                
                DispatchQueue.main.async {
                    successText = "Рецепт сохранён! ✅"
                    isSaving = false
                    
                    // Очищаем форму
                    title = ""
                    timeText = ""
                    servings = ""
                    difficulty = "medium"
                    ingredientsText = ""
                    instructions = ""
                    selectedCuisineId = nil
                    
                    // Скрываем сообщение через 2 секунды
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        successText = nil
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
}

// MARK: - Mouse Sticker

private struct MouseSticker: View {
    let name: String
    let size: CGFloat
    
    var body: some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview {
    AddRecipeView()
}
