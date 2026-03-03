import SwiftUI

struct AddRecipeView: View {

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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground(.list)

                ScrollView {
                    VStack(spacing: 16) {

                        header

                        if let errorText {
                            messageView(text: errorText, color: .red)
                        }

                        if let successText {
                            messageView(text: successText, color: .green)
                        }

                        formCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "..." : "Сохранить") {
                        save()
                    }
                    .disabled(isSaving)
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

    private var header: some View {
        HStack(spacing: 16) {
            Image("mouse_pen")
                .resizable()
                .scaledToFit()
                .frame(width: 90, height: 90)

            VStack(alignment: .leading) {
                Text("Добавить")
                    .font(.title.bold())
                Text("новый рецепт")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Form Card

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 18) {

            Text("Основное").font(.headline)

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

            Text("Ингредиенты").font(.headline)

            TextEditor(text: $ingredientsText)
                .frame(minHeight: 100)
                .padding(6)
                .background(.regularMaterial)
                .cornerRadius(8)

            Divider()

            Text("Шаги").font(.headline)

            TextEditor(text: $instructions)
                .frame(minHeight: 120)
                .padding(6)
                .background(.regularMaterial)
                .cornerRadius(8)
        }
        .padding(18)
        .glassCard()
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

    // MARK: - Cuisine Menu

    private var cuisineMenu: some View {
        Menu {
            Button("Не выбрано") {
                selectedCuisineId = nil
            }

            Divider()

            ForEach(cuisines) { cuisine in
                Button(cuisine.name) {
                    selectedCuisineId = cuisine.id
                }
            }

            Divider()

            Button("➕ Добавить кухню") {
                showAddCuisine = true
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
        guard let id = selectedCuisineId else { return "Не выбрано" }
        return cuisines.first(where: { $0.id == id })?.name ?? "Не выбрано"
    }

    // MARK: - Load

    private func loadCategories() {
        categories = (try? DatabaseManager.shared.fetchCategories()) ?? []
        if selectedCategoryId == -1 {
            selectedCategoryId = categories.first?.id ?? -1
        }
    }

    private func loadCuisines() {
        cuisines = (try? DatabaseManager.shared.fetchCuisines()) ?? []
    }

    // MARK: - Save

    private func save() {

        errorText = nil
        successText = nil

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else {
            errorText = "Добавь название"
            return
        }

        let cleanInstructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanInstructions.isEmpty else {
            errorText = "Добавь шаги приготовления"
            return
        }

        let timeMinutes = Int(timeText) ?? 0

        let lines = ingredientsText
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // ✅ правильный фрагмент
        var cuisineName: String? = nil

        if let id = selectedCuisineId,
           let cuisine = cuisines.first(where: { $0.id == id }) {
            cuisineName = cuisine.name
        }

        do {
            try DatabaseManager.shared.addRecipe(
                title: cleanTitle,
                categoryId: selectedCategoryId,
                cuisineName: cuisineName,
                difficulty: difficulty,
                timeMinutes: timeMinutes,
                servingsText: servings.isEmpty ? nil : servings,
                instructions: cleanInstructions,
                ingredientsLines: lines
            )

            successText = "Рецепт сохранён ✅"

            title = ""
            timeText = ""
            servings = ""
            difficulty = "medium"
            ingredientsText = ""
            instructions = ""
            selectedCuisineId = nil

        } catch {
            errorText = error.localizedDescription
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
    AddRecipeView()
}
