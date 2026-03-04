import SwiftUI

struct AddRecipeView: View {

    // MARK: - Data

    @State private var categories: [CategoryRow] = []
    @State private var selectedCategoryId: Int = -1

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
                    .padding(.horizontal,20)
                    .padding(.bottom,20)
                }
            }
            .navigationTitle("")
            .toolbar {

                ToolbarItem(placement:.topBarTrailing) {

                    Button(isSaving ? "..." : "Сохранить") {
                        save()
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear {
                loadCategories()
            }
        }
    }

    // MARK: HEADER

    private var header: some View {

        HStack(spacing:16) {

            Image("mouse_pen")
                .resizable()
                .scaledToFit()
                .frame(width:90,height:90)

            VStack(alignment:.leading) {

                Text("Добавить")
                    .font(.title.bold())

                Text("новый рецепт")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: FORM

    private var formCard: some View {

        VStack(alignment:.leading, spacing:18) {

            Text("Основное")
                .font(.headline)

            TextField("Название", text:$title)
                .textFieldStyle(.roundedBorder)

            categoryMenu

            Picker("Сложность", selection:$difficulty) {
                Text("легко").tag("easy")
                Text("средне").tag("medium")
                Text("сложно").tag("hard")
            }
            .pickerStyle(.segmented)

            HStack {

                TextField("Минуты", text:$timeText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)

                TextField("Порции", text:$servings)
                    .textFieldStyle(.roundedBorder)
            }

            Divider()

            Text("Ингредиенты")
                .font(.headline)

            TextEditor(text:$ingredientsText)
                .frame(minHeight:100)
                .padding(6)
                .background(.regularMaterial)
                .cornerRadius(8)

            Divider()

            Text("Шаги")
                .font(.headline)

            TextEditor(text:$instructions)
                .frame(minHeight:120)
                .padding(6)
                .background(.regularMaterial)
                .cornerRadius(8)
        }
        .padding(18)
        .glassCard()
    }

    // MARK: CATEGORY

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

        categories
            .first(where:{ $0.id == selectedCategoryId })?
            .name ?? "Выберите"
    }

    // MARK: LOAD

    private func loadCategories() {

        categories = (try? DatabaseManager.shared.fetchCategories()) ?? []

        if selectedCategoryId == -1 {
            selectedCategoryId = categories.first?.id ?? -1
        }
    }

    // MARK: SAVE (временно)

    private func save() {

        errorText = nil
        successText = nil

        let cleanTitle = title.trimmingCharacters(in:.whitespacesAndNewlines)

        guard !cleanTitle.isEmpty else {
            errorText = "Добавь название"
            return
        }

        guard !instructions.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else {
            errorText = "Добавь шаги приготовления"
            return
        }

        successText = "Форма работает. Сохранение добавим следующим шагом."

        title = ""
        timeText = ""
        servings = ""
        ingredientsText = ""
        instructions = ""
    }

    // MARK: MESSAGE

    private func messageView(text:String,color:Color) -> some View {

        Text(text)
            .font(.caption)
            .foregroundStyle(color)
            .padding(8)
            .frame(maxWidth:.infinity,alignment:.leading)
            .background(.regularMaterial)
            .cornerRadius(8)
    }
}

#Preview {
    AddRecipeView()
}
