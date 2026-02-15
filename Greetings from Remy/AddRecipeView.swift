import SwiftUI

struct AddRecipeView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var categories: [CategoryRow] = []
    @State private var selectedCategoryId: Int = -1

    @State private var title = ""
    @State private var cuisine = ""              // строка кухни (как было)
    @State private var timeText = ""
    @State private var servings = ""
    @State private var difficulty = "medium"

    @State private var ingredientsText = ""
    @State private var instructions = ""

    @State private var errorText: String?
    @State private var successText: String?

    // ✅ одна точка управления стилем экрана
    private enum UI {
        static let headerMouseSize: CGFloat = 110
        static let headerTopPadding: CGFloat = 10
        static let headerSidePadding: CGFloat = 16

        static let blockRadius: CGFloat = 28
        static let blockOpacity: Double = 0.55

        static let sectionTitleTop: CGFloat = 10
        static let sectionTitleBottom: CGFloat = 6

        // кухня-плашки
        static let cuisineMouseSize: CGFloat = 95     // как на главном
        static let cuisineRowHeight: CGFloat = 110
        static let cuisineSpacing: CGFloat = 14
    }

    // 7 кухонь: добавили Домашнюю
    private let cuisineItems: [(title: String, asset: String)] = [
        ("Домашняя",     "cat_cuisines_home"),
        ("Русская",      "cat_cuisines_russian"),
        ("Европейская",  "cat_cuisines_european"),
        ("Итальянская",  "cat_cuisines_italian"),
        ("Греческая",    "cat_cuisines_greese"),
        ("Французская",  "cat_cuisines_french"),
        ("Азиатская",    "cat_cuisines_asian")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {

                        header

                        // MARK: Основное
                        Text("Основное")
                            .font(.headline)
                            .foregroundStyle(.primary.opacity(0.75))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, UI.headerSidePadding)
                            .padding(.top, UI.sectionTitleTop)
                            .padding(.bottom, UI.sectionTitleBottom)

                        // Полупрозрачная плашка: Название
                        GlassInputField(
                            placeholder: "Название",
                            text: $title
                        )
                        .padding(.horizontal, UI.headerSidePadding)

                        // 7 плашек кухонь (в один столбик, как карточки каталога)
                        VStack(spacing: UI.cuisineSpacing) {
                            ForEach(cuisineItems, id: \.title) { item in
                                CuisineCard(
                                    title: item.title,
                                    asset: item.asset,
                                    isSelected: cuisine == item.title,
                                    mouseSize: UI.cuisineMouseSize,
                                    height: UI.cuisineRowHeight
                                ) {
                                    // тап по выбранной = снять выбор
                                    cuisine = (cuisine == item.title) ? "" : item.title
                                }
                            }
                        }
                        .padding(.horizontal, UI.headerSidePadding)

                        // MARK: Остальные поля (можно оставить как есть, но тоже “стеклом”)
                        VStack(spacing: 12) {
                            // Категория
                            GlassPickerRow(
                                title: "Категория",
                                valueText: categories.first(where: { $0.id == selectedCategoryId })?.name ?? "—"
                            ) {
                                Picker("Категория", selection: $selectedCategoryId) {
                                    ForEach(categories) { c in
                                        Text(c.name).tag(c.id)
                                    }
                                }
                                .pickerStyle(.menu)
                            }

                            // Сложность
                            GlassSegmentedDifficulty(selection: $difficulty)

                            // Время + порции
                            HStack(spacing: 12) {
                                GlassInputField(placeholder: "Время (мин)", text: $timeText)
                                    .keyboardType(.numberPad)

                                GlassInputField(placeholder: "Порции (опционально)", text: $servings)
                            }

                            // Ингредиенты
                            GlassTextArea(
                                title: "Ингредиенты",
                                subtitle: "Каждая строка: Ингредиент — Количество",
                                text: $ingredientsText,
                                minHeight: 120
                            )

                            // Шаги
                            GlassTextArea(
                                title: "Шаги",
                                subtitle: nil,
                                text: $instructions,
                                minHeight: 160
                            )
                        }
                        .padding(.horizontal, UI.headerSidePadding)
                        .padding(.top, 8)

                        // Ошибки/успех
                        if let errorText {
                            Text(errorText)
                                .foregroundStyle(.red)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .glassCard(radius: UI.blockRadius, opacity: UI.blockOpacity)
                                .padding(.horizontal, UI.headerSidePadding)
                        }

                        if let successText {
                            Text(successText)
                                .foregroundStyle(.green)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .glassCard(radius: UI.blockRadius, opacity: UI.blockOpacity)
                                .padding(.horizontal, UI.headerSidePadding)
                        }

                        Spacer(minLength: 26)
                    }
                    .padding(.top, 6)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .tabBar)
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") { save() }
                }
            }
            .onAppear { loadCategories() }
        }
    }

    // MARK: - Header (как каталог)
    private var header: some View {
        HStack(spacing: 12) {
            MouseSticker("mouse_pen", size: UI.headerMouseSize)

            Text("Добавить")
                .font(.title3.weight(.semibold)) // как в каталоге
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, UI.headerSidePadding)
        .padding(.top, UI.headerTopPadding)
    }

    // MARK: - Data
    private func loadCategories() {
        do {
                try DatabaseManager.shared.normalizeCategoriesForUI()   // ✅ вот это
                categories = try DatabaseManager.shared.fetchCategories()

                if selectedCategoryId == -1, let first = categories.first {
                    selectedCategoryId = first.id
                }
            } catch {
                errorText = error.localizedDescription
            }
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

            let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanTitle.isEmpty {
                errorText = "Добавь название рецепта"
                return
            }

            let cleanInstructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanInstructions.isEmpty {
                errorText = "Добавь шаги приготовления"
                return
            }

            try DatabaseManager.shared.addRecipe(
                title: cleanTitle,
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

// MARK: - Components

private struct CuisineCard: View {
    let title: String
    let asset: String
    let isSelected: Bool
    let mouseSize: CGFloat
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .leading) {

                // текст слева, место справа под мыша
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    
                }
                .padding(.trailing, mouseSize * 0.95)

                HStack {
                    Spacer()
                    MouseSticker(asset, size: mouseSize)
                        .offset(x: 4, y: -2)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .glassCard(radius: 28, opacity: 0.55)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(isSelected ? 0.24 : 0.0), lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.01 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.85), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
    }
}

private struct GlassInputField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .glassCard(radius: 22, opacity: 0.55)
    }
}

private struct GlassPickerRow<PickerContent: View>: View {
    let title: String
    let valueText: String
    @ViewBuilder var picker: () -> PickerContent

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            picker()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .glassCard(radius: 22, opacity: 0.55)
    }
}

private struct GlassSegmentedDifficulty: View {
    @Binding var selection: String

    var body: some View {
        Picker("Сложность", selection: $selection) {
            Text("легко").tag("easy")
            Text("средне").tag("medium")
            Text("сложно").tag("hard")
        }
        .pickerStyle(.segmented)
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .glassCard(radius: 22, opacity: 0.55)
    }
}

private struct GlassTextArea: View {
    let title: String
    let subtitle: String?
    @Binding var text: String
    let minHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary.opacity(0.85))

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextEditor(text: $text)
                .frame(minHeight: minHeight)
                .scrollContentBackground(.hidden)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .glassCard(radius: 22, opacity: 0.55)
    }
}

// ✅ “съедает” прозрачные поля PNG, как у нас в каталоге
private struct MouseSticker: View {
    let name: String
    let size: CGFloat

    init(_ name: String, size: CGFloat = 52) {
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
