import SwiftUI

struct FavoritesView: View {
    // MARK: - State
    
    @State private var items: [RecipeRow] = []
    @State private var errorText: String?
    @State private var isLoading = false
    
    // MARK: - Constants
    
    private enum Constants {
        static let mouseLoveSize: CGFloat = 190
        static let headerTopPadding: CGFloat = 10
        static let headerSidePadding: CGFloat = 20
        
        static let cardRadius: CGFloat = 22
        static let cardOpacity: Double = 0.6
        static let cardVPadding: CGFloat = 14
        static let cardHPadding: CGFloat = 16
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground(.list)
                
                content
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .tabBar)
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    refreshButton
                }
            }
            .onAppear(perform: load)
        }
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                headerRow
                
                if isLoading {
                    loadingView
                } else if let errorText = errorText {
                    errorView(errorText)
                } else if items.isEmpty {
                    emptyView
                } else {
                    itemsList
                }
            }
            .padding(.bottom, 28)
        }
    }
    
    // MARK: - Header
    
    private var headerRow: some View {
        HStack(spacing: 16) {
            MouseSticker(name: "mouse_love", size: Constants.mouseLoveSize)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Избранное")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                
                if !items.isEmpty {
                    Text("\(items.count) \(pluralize(items.count))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, Constants.headerSidePadding)
        .padding(.top, Constants.headerTopPadding)
    }
    
    // MARK: - States
    
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
        .padding(.horizontal, Constants.headerSidePadding)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse, options: .repeating)
            
            Text("Пока пусто")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            
            Text("Добавь рецепты в избранное, и они появятся здесь")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.vertical, 60)
        .glassCard()
        .padding(.horizontal, Constants.headerSidePadding)
    }
    
    // MARK: - Items List
    
    private var itemsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(items) { recipe in
                NavigationLink {
                    RecipeDetailView(recipeId: recipe.id, title: recipe.title)
                } label: {
                    FavoriteCardRow(
                        title: recipe.title,
                        subtitle: "\(recipe.timeMinutes) мин  •  \(diffLabel(recipe.difficulty))"
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Constants.headerSidePadding)
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Toolbar
    
    private var refreshButton: some View {
        Button(action: load) {
            Image(systemName: "arrow.clockwise")
                .font(.headline)
                .foregroundStyle(.primary)
                .rotationEffect(.degrees(isLoading ? 360 : 0))
                .animation(
                    isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                    value: isLoading
                )
        }
        .disabled(isLoading)
    }
    
    // MARK: - Data
    
    private func load() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let favorites = try DatabaseManager.shared.fetchFavoriteRecipes()
                
                DispatchQueue.main.async {
                    items = favorites
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
    
    // MARK: - Helpers
    
    private func diffLabel(_ diff: String) -> String {
        switch diff {
        case "easy": return "легко"
        case "hard": return "сложно"
        default: return "средне"
        }
    }
    
    private func pluralize(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        
        if mod10 == 1 && mod100 != 11 {
            return "рецепт"
        } else if mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20) {
            return "рецепта"
        } else {
            return "рецептов"
        }
    }
}

// MARK: - Favorite Card Row

private struct FavoriteCardRow: View {
    // MARK: - Properties
    
    let title: String
    let subtitle: String
    
    // MARK: - State
    
    @State private var isPressed = false
    
    // MARK: - Constants
    
    private let radius: CGFloat = 22
    private let vPad: CGFloat = 14
    private let hPad: CGFloat = 16
    
    // MARK: - Body
    
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
            
            // Анимированная стрелочка
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .offset(x: isPressed ? 5 : 0)
        }
        .padding(.vertical, vPad)
        .padding(.horizontal, hPad)
        .glassCard(radius: radius)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onTapGesture {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isPressed = false
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
    FavoritesView()
}
