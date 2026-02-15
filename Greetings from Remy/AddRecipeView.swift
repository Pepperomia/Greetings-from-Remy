import SwiftUI

struct AddRecipeView: View {
    @Environment(\.dismiss) private var dismiss

    // Data
    @State private var categories: [CategoryRow] = []
    @State private var cuisines: [CuisineRow] = []
    @State private var selectedCategoryId: Int = -1
    @State private var selectedCuisineId: Int? = nil

    // Fields
    @State private var title = ""
    @State private var timeText = ""
    @State private var servings = ""
    @State private var difficulty = "medium"
    @State private var ingredientsText = ""
    @State private var instructions = ""

    // UI
    @State private var errorText: String?
    @State private var successText: String?
    @State private var showAddCuisine = false

    private enum UI {
        static let headerMouseSize: CGFloat = 110
        static let headerSidePadding: CGFloat = 16
        static let headerTopPadding: CGFloat = 10

        static let glassCorner: CGFloat = 18
        static let glassStrokeOpacity: Double = 0.18
        static let glassVPad: CGFloat = 10
        static let glassHPad: CGFloat = 14
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 10) {
                    headerRow

                    Form {
                        Section("Основное") {
                            TextField("Название", text: $title)

                            // Категория (как было)
                            Picker("Категория", selection: $selectedCategoryId) {
                                ForEach(categories) { c in
                                    Text(c.name).tag(c.id)
                                }
                            }

                            // ✅ КУХНИ МИРА: стеклянная плашка + выпадающий список
                            cuisineGlassMenuRow

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
                            Section { Text(errorText).foregroundStyle(.red) }
                        }
                        if let successText {
                            Section { Text(successText).foregroundStyle(.green) }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") { save() }
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

    // MARK: - Header (mouse_pen + “Добавить” как в каталоге)

    private var headerRow: some View {
        HStack(spacing: 12) {
            MouseSticker("mouse_pen", size: UI.headerMouseSize)

            Text("Добавить")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, UI.headerSidePadding)
        .padding(.top, UI.headerTopPadding)
    }

    // MARK: - Cuisine glass row (Menu)

    private var cuisineGlassMenuRow: some View {
        Menu {
            Button("Не выбрано") { selectedCuisineId = nil }

            ForEach(cuisines) { cu in
                Button(cu.name) { selectedCuisineId = cu.id }
            }

        } label: {
            HStack(spacing: 10) {
                Text("Кухни мира")
                    .foregroundStyle(.primary)

                Spacer()

                Text(selectedCuisineTitle)
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, UI.glassVPad)
            .padding(.horizontal, UI.glassHPad)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: UI.glassCorner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: UI.glassCorner, style: .continuous)
                    .stroke(.white.opacity(UI.glassStrokeOpacity), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private var selectedCuisineTitle: String {
        guard let id = selectedCuisineId else { return "Не выбрано" }
        return cuisines.first(where: { $0.id == id })?.name ?? "Не выбрано"
    }

    // MARK: - Loads

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
            let raw = try DatabaseManager.shared.fetchAllCuisines()

            // ✅ 1) trim
            // ✅ 2) первая буква заглавная
            // ✅ 3) дедуп по lowercased(trim) -> уберёт “азиатская” дубль
            var dict: [String: CuisineRow] = [:]
            dict.reserveCapacity(raw.count)

            for cu in raw {
                let trimmed = cu.name.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }

                let pretty: String = {
                    guard let first = trimmed.first else { return trimmed }
                    return String(first).uppercased() + trimmed.dropFirst()
                }()

                let key = pretty.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

                // если дубль — оставляем тот, у которого имя уже “красивее” (с большой),
                // а если оба одинаковые — оставляем первый
                if let existing = dict[key] {
                    let existingIsCapitalized = existing.name.first.map { String($0) == String($0).uppercased() } ?? false
                    let newIsCapitalized = pretty.first.map { String($0) == String($0).uppercased() } ?? false

                    if !existingIsCapitalized && newIsCapitalized {
                        dict[key] = CuisineRow(id: cu.id, name: pretty)
                    }
                } else {
                    dict[key] = CuisineRow(id: cu.id, name: pretty)
                }
            }

            cuisines = dict.values.sorted { $0.name < $1.name }

        } catch {
            errorText = "Ошибка кухонь: \(error.localizedDescription)"
            cuisines = []
        }
    }

    // MARK: - Save

    private func save() {
        do {
            errorText = nil
            successText = nil

            let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanTitle.isEmpty {
                errorText = "Добавь название"
                return
            }

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

            let cuisineName: String? = {
                guard let id = selectedCuisineId else { return nil }
                return cuisines.first(where: { $0.id == id })?.name
            }()

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

            successText = "Сохранено ✅"

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

    // MARK: - Mouse sticker helper (как у вас)

    private struct MouseSticker: View {
        let name: String
        let size: CGFloat

        init(_ name: String, size: CGFloat) {
            self.name = name
            self.size = size
        }

        var body: some View {
            Image(name)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipped()
                .accessibilityHidden(true)
        }
    }
}
