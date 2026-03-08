import SwiftUI

struct RecipesListView: View {

    let category: CategoryRow

    @State private var items: [RecipeRow] = []
    @State private var errorText: String?
    @State private var showingDeleteAlert = false
    @State private var isDeleting = false
    @State private var showingDeleteManagement = false // Добавлено

    @State private var filter30 = false
    @State private var sortByCalories = false
    @State private var surpriseRecipeId: Int?

    @State private var isLoading = false
    
    @State private var originalItems: [RecipeRow] = []
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {

        ZStack {

            AppBackground(.list)

            ScrollView {

                VStack(spacing: 24) {

                    filtersRow

                    if isLoading {

                        ProgressView()
                            .padding(.top, 40)

                    } else if let errorText = errorText {

                        errorView(errorText: errorText)

                    } else if items.isEmpty {

                        emptyView()

                    } else {

                        recipesList
                    }
                    
                    // Кнопка управления удалением - всегда внизу
                    deleteManagementButton
                        .padding(.top, 20)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(category.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: surpriseBinding) {
            if let id = surpriseRecipeId {
                RecipeDetailView(recipeId: id)
            }
        }
        .alert("Удаление категории", isPresented: $showingDeleteAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Удалить", role: .destructive) {
                deleteCategory()
            }
        } message: {
            Text("Вы уверены, что хотите удалить категорию «\(category.displayName)»?")
        }
        .sheet(isPresented: $showingDeleteManagement) { // Добавлено
            DeleteManagementView()
        }
        .onAppear {
            loadRecipes()
        }
        .onChange(of: filter30) { _, _ in
            loadRecipes()
        }
        .onChange(of: sortByCalories) { _, newValue in
            if newValue {
                sortRecipesByCalories()
            } else {
                items = originalItems
            }
        }
    }
    
    // MARK: - Delete Management Button (новая кнопка)
    
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
    
    // MARK: - Delete Category Button
    
    private var deleteCategoryButton: some View {
        Button(action: {
            showingDeleteAlert = true
        }) {
            HStack {
                if isDeleting {
                    ProgressView()
                        .tint(.red)
                } else {
                    Image(systemName: "trash")
                }
                Text("Удалить категорию")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.regularMaterial)
            .foregroundColor(.red)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(isDeleting)
    }
    
    // MARK: - Delete Category Function
    
    private func deleteCategory() {
        isDeleting = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try DatabaseManager.shared.deleteCategory(id: category.id)
                
                DispatchQueue.main.async {
                    isDeleting = false
                    dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    errorText = error.localizedDescription
                    isDeleting = false
                    showingDeleteAlert = false
                }
            }
        }
    }
    
    // MARK: - View Builders
    
    func errorView(errorText: String) -> some View {
        Text(errorText)
            .foregroundStyle(.red)
            .padding(.top, 40)
    }
    
    func emptyView() -> some View {
        VStack(spacing: 20) {
            Text("В этой категории нет рецептов")
                .foregroundStyle(.secondary)
                .padding(.top, 40)
            
            // Кнопка удаления пустой категории
            deleteCategoryButton
        }
    }
}

// MARK: Bindings
private extension RecipesListView {
    var surpriseBinding: Binding<Bool> {
        Binding(
            get: { surpriseRecipeId != nil },
            set: { if !$0 { surpriseRecipeId = nil } }
        )
    }
}

// MARK: Filters
private extension RecipesListView {

    var filtersRow: some View {

        HStack(spacing: 25) {

            filterButton(
                image: "mouse_watch",
                title: "до 30 мин",
                isActive: filter30
            ) {
                filter30.toggle()
            }

            filterButton(
                image: "mouse_cube",
                title: "Сюрприз",
                isActive: false
            ) {
                surpriseMe()
            }
            
            filterButton(
                image: "mouse_weight",
                title: "Калории",
                isActive: sortByCalories
            ) {
                sortByCalories.toggle()
            }
        }
        .padding(.top, 16)
        .frame(maxWidth: .infinity)
    }

    func filterButton(
        image: String,
        title: String,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {

        Button(action: action) {

            VStack(spacing: 8) {

                Image(image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 110)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(BounceButtonStyle())
        .opacity(isActive ? 0.6 : 1.0)
    }
}

// MARK: List
private extension RecipesListView {

    var recipesList: some View {

        LazyVStack(spacing: 16) {

            ForEach(items) { recipe in
                NavigationLink {
                    RecipeDetailView(recipeId: recipe.id)
                } label: {
                    RecipeCardRow(recipe: recipe)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                        .completeCardAnimation(glowColor: .orange)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.top, 8)
    }
}

// MARK: Data
private extension RecipesListView {

    func loadRecipes() {

        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {

            do {

                let maxMinutes = filter30 ? 30 : nil

                let recipes = try DatabaseManager.shared.fetchRecipes(
                    categoryId: category.id,
                    maxMinutes: maxMinutes
                )

                DispatchQueue.main.async {

                    let testRecipes = recipes.map { recipe -> RecipeRow in
                        return RecipeRow(
                            id: recipe.id,
                            title: recipe.title,
                            timeMinutes: recipe.timeMinutes,
                            difficulty: recipe.difficulty,
                            calories: Int.random(in: 100...800)
                        )
                    }
                    
                    self.originalItems = testRecipes
                    self.items = testRecipes
                    
                    for recipe in testRecipes {
                        print("Рецепт: \(recipe.title), калории: \(recipe.calories?.description ?? "nil")")
                    }
                    
                    if self.sortByCalories {
                        self.sortRecipesByCalories()
                    }
                    
                    self.isLoading = false
                }

            } catch {

                DispatchQueue.main.async {
                    self.errorText = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    func sortRecipesByCalories() {
        items.sort { recipe1, recipe2 in
            let calories1 = recipe1.calories ?? 0
            let calories2 = recipe2.calories ?? 0
            return calories1 < calories2
        }
    }

    func surpriseMe() {

        guard !items.isEmpty else { return }

        surpriseRecipeId = items.randomElement()?.id
    }
}

// MARK: Card
private struct RecipeCardRow: View {

    let recipe: RecipeRow

    var body: some View {

        HStack {

            VStack(alignment: .leading, spacing: 8) {

                Text(recipe.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack(spacing: 10) {

                    Text(recipe.timeText)

                    if !recipe.timeText.isEmpty {
                        Text("•")
                    }

                    Text(recipe.difficultyText)
                    
                    if let calories = recipe.calories, calories > 0 {
                        Text("•")
                        Text("\(calories) ккал")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .opacity(0.7)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(
            color: .black.opacity(0.1),
            radius: 15,
            x: 0,
            y: 8
        )
    }
}

// MARK: Button animation
struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25), value: configuration.isPressed)
    }
}
