import SwiftUI

struct RecipesListView: View {
    // MARK: - Properties
    
    let category: CategoryRow
    
    // MARK: - State
    
    @State private var items: [RecipeRow] = []
    @State private var errorText: String?
    
    @State private var cuisines: [CuisineRow] = []
    @State private var selectedCuisineId: Int? = nil
    
    @State private var filter30 = false
    @State private var surpriseRecipeId: Int? = nil
    
    @State private var showAddCuisine = false
    @State private var isLoading = false
    
    // MARK: - UI Constants
    
    private enum UI {
        static let mouseSize: CGFloat = 140
        static let headerTopPadding: CGFloat = 10
        static let headerSidePadding: CGFloat = 20  // Увеличила для отступов
        
        static let cardRadius: CGFloat = 22  // Вернула как было
        static let cardVPad: CGFloat = 14    // Вернула как было
        static let cardHPad: CGFloat = 24    // Вернула как было
        
        static let selectedRingOpacity: Double = 0.35
        static let ringWidth: CGFloat = 2
        
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            AppBackground(.list)
            
            content
        }
        .navigationTitle(category.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Сброс") {
                    withAnimation {
                        resetFilters()
                    }
                }
                .disabled(selectedCuisineId == nil && !filter30)
                .opacity(selectedCuisineId == nil && !filter30 ? 0.5 : 1)
            }
        }
        .navigationDestination(item: $surpriseRecipeId) { id in
            RecipeDetailView(recipeId: id, title: "Рецепт")
        }
        .sheet(isPresented: $showAddCuisine) {
            AddCuisineSheet {
                loadCuisines()
            }
        }
        .onAppear {
            loadCuisines()
            loadRecipes()
        }
        .onChange(of: selectedCuisineId) { _, _ in loadRecipes() }
        .onChange(of: filter30) { _, _ in loadRecipes() }
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Фильтры
                filtersRow
                    .padding(.top, UI.headerTopPadding)
                
                // Результаты
                if isLoading {
                    loadingView
                } else if let errorText = errorText {
                    errorView(errorText)
                } else if items.isEmpty {
                    emptyView
                } else {
                    recipesList
                }
            }
            .padding(.bottom, 28)
        }
    }
    
    // MARK: - Filters Row
    
    private var filtersRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                timeFilterButton
                    .frame(width: UI.mouseSize, height: UI.mouseSize)
                Spacer()
                cuisineMenuButton
                    .frame(width: UI.mouseSize, height: UI.mouseSize)
                Spacer()
                surpriseButton
                    .frame(width: UI.mouseSize, height: UI.mouseSize)
            }
            .padding(.horizontal, UI.headerSidePadding)
        }
    }

    
    private var timeFilterButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                filter30.toggle()
            }
            loadRecipes()
        } label: {
            VStack(spacing: 8) {
                MouseSticker(name: "mouse_watch", size: UI.mouseSize)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(filter30 ? UI.selectedRingOpacity : 0),
                                    lineWidth: UI.ringWidth)
                    )
                
                Text("до 30 мин")
                    .font(.caption)
                    .foregroundStyle(filter30 ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var cuisineMenuButton: some View {
        Menu {
            Button("Все кухни") {
                selectedCuisineId = nil
                loadRecipes()
            }
            
            if !cuisines.isEmpty {
                Divider()
                ForEach(cuisines) { cuisine in
                    Button(cuisine.displayName) {
                        selectedCuisineId = cuisine.id
                        loadRecipes()
                    }
                }
            }
            
            Divider()
            
            Button("➕ Добавить кухню") {
                showAddCuisine = true
            }
        } label: {
            VStack(spacing: 8) {
                MouseSticker(name: "mouse_world", size: UI.mouseSize)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(selectedCuisineId != nil ? UI.selectedRingOpacity : 0),
                                    lineWidth: UI.ringWidth)
                    )
                
                Text(selectedCuisineName)
                    .font(.caption)
                    .foregroundStyle(selectedCuisineId != nil ? .primary : .secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var surpriseButton: some View {
        Button {
            surpriseMe()
        } label: {
            VStack(spacing: 8) {
                MouseSticker(name: "mouse_cube", size: UI.mouseSize)
                
                Text("Сюрприз")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Recipes List
    
    private var recipesList: some View {
        LazyVStack(spacing: 12) {
            ForEach(items) { recipe in
                NavigationLink {
                    RecipeDetailView(recipeId: recipe.id, title: recipe.title)
                } label: {
                    RecipeCardRow(
                        title: recipe.title,
                        subtitle: "\(recipe.timeMinutes) мин • \(diffLabel(recipe.difficulty))"
                    )
                    .frame(maxWidth: 350)  // ограничиваем ширину
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, UI.headerSidePadding)
    }
    
    // MARK: - Helper Views
    
    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 40)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            Text("Ошибка: \(error)")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .glassCard()
        .padding(.horizontal, UI.headerSidePadding)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("Нет рецептов")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            
            Text("В этой категории пока нет рецептов\nс выбранными фильтрами")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 60)
        .glassCard()
        .padding(.horizontal, UI.headerSidePadding)
    }
    
    // MARK: - Computed Properties
    
    private var selectedCuisineName: String {
        guard let id = selectedCuisineId else { return "Кухня" }
        return cuisines.first(where: { $0.id == id })?.displayName ?? "Кухня"
    }
    
    // MARK: - Data Loading
    
    private func loadCuisines() {
        do {
            errorText = nil
            cuisines = try DatabaseManager.shared.fetchCuisines()
        } catch {
            print("❌ Ошибка загрузки кухонь: \(error)")
            cuisines = []
        }
    }
    
    private func loadRecipes() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let maxMin = filter30 ? 30 : nil
                
                let recipes = try DatabaseManager.shared.searchRecipes(
                    query: "",
                    ingredients: nil,
                    categoryId: category.id,
                    cuisineId: selectedCuisineId,
                    maxMinutes: maxMin,
                    onlyEasy: false
                )
                
                DispatchQueue.main.async {
                    items = recipes
                    errorText = nil
                    isLoading = false
                }
                
            } catch {
                DispatchQueue.main.async {
                    errorText = error.localizedDescription
                    items = []
                    isLoading = false
                }
            }
        }
    }
    
    private func surpriseMe() {
        do {
            errorText = nil
            let maxMin = filter30 ? 30 : nil
            
            if let id = try DatabaseManager.shared.randomRecipeId(
                query: "",
                ingredients: nil,
                categoryId: category.id,
                cuisineId: selectedCuisineId,
                maxMinutes: maxMin,
                onlyEasy: false
            ) {
                surpriseRecipeId = id
            } else {
                errorText = "Ничего не найдено 🙃"
            }
        } catch {
            errorText = error.localizedDescription
        }
    }
    
    private func resetFilters() {
        selectedCuisineId = nil
        filter30 = false
        loadRecipes()
    }
    
    // MARK: - Helpers
    
    private func diffLabel(_ diff: String) -> String {
        switch diff {
        case "easy": return "легко"
        case "hard": return "сложно"
        default: return "средне"
        }
    }
}

// MARK: - Recipe Card Row

private struct RecipeCardRow: View {
    let title: String
    let subtitle: String
    
    // Убрали isPressed и onTapGesture полностью!
    
    private let cardRadius: CGFloat = 24
    private let cardVPad: CGFloat = 16
    private let cardHPad: CGFloat = 18
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, cardVPad)
        .padding(.horizontal, cardHPad)
        .background(
            RoundedRectangle(cornerRadius: cardRadius)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cardRadius)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
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
            .clipShape(Circle())
            .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RecipesListView(category: CategoryRow.preview)
    }
}
