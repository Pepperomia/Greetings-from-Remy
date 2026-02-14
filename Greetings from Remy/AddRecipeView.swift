import SwiftUI

struct AddRecipeView: View {
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

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                Form {
                    // ✅ Стикер с мышью ВНУТРИ Form
                    Section {
                        HStack {
                            Spacer()
                            Image("mouse_clover") // временно, пока нет mouse_add
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 120)
                                .opacity(0.95)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowBackground(Color.clear)

                    Section("Основное") {
                        TextField("Название", text: $title)
                        
                        HStack(spacing: 8) {
                            Button("Азиатская") { cuisine = "Азиатская" }
                                .buttonStyle(.bordered)
                            Button("Русская") { cuisine = "Русская" }
                                .buttonStyle(.bordered)
                            Button("Итальянская") { cuisine = "Итальянская" }
                                .buttonStyle(.bordered)
                            Button("Греческая") { cuisine = "Греческая" }
                                .buttonStyle(.bordered)
                            Button("Европейская") { cuisine = "Европейская" }
                                .buttonStyle(.bordered)
                        }

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
                            .frame(minHeight: 120)
                    }

                    Section("Шаги") {
                        TextEditor(text: $instructions)
                            .frame(minHeight: 160)
                    }

                    if let errorText {
                        Section {
                            Text(errorText).foregroundStyle(.red)
                        }
                    }

                    if let successText {
                        Section {
                            Text(successText).foregroundStyle(.green)
                        }
                    }
                }
                .scrollContentBackground(.hidden) // ✅ чтобы был виден фон
            }
            .navigationTitle("Добавить")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") { save() }
                }
            }
            .onAppear { loadCategories() }
        }
    }

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

    private func save() {
        do {
            errorText = nil
            successText = nil

            let timeMinutes = Int(timeText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            let lines = ingredientsText
                .split(separator: "\n")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let cleanInstructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanInstructions.isEmpty {
                errorText = "Добавь шаги приготовления"
                return
            }

            try DatabaseManager.shared.addRecipe(
                title: title,
                categoryId: selectedCategoryId,
                cuisineName: cuisine.isEmpty ? nil : cuisine,
                difficulty: difficulty,
                timeMinutes: timeMinutes,
                servingsText: servings.isEmpty ? nil : servings,
                instructions: cleanInstructions,
                ingredientsLines: lines
            )

            successText = "Сохранено ✅"
            title = ""
            cuisine = ""
            timeText = ""
            servings = ""
            difficulty = "medium"
            ingredientsText = ""
            instructions = ""

        } catch {
            errorText = error.localizedDescription
        }
    }
}
