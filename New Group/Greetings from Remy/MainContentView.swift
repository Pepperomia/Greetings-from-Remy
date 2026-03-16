import SwiftUI

struct MainContentView: View {
    
    // MARK: - State
    
    @State private var selectedTab = 0
    @State private var didBootstrap = false
    @State private var showSplash = true
    @State private var bootstrapError: String?
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            if showSplash {
                splashView
                    .transition(.opacity.combined(with: .scale))
                    .zIndex(1)
            } else {
                mainContent
            }
        }
        .onAppear {
            bootstrap()
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        TabView(selection: $selectedTab) {
            
            // 1. Каталог
            CategoriesView()
                .tabItem {
                    Label("Каталог", systemImage: "book.closed")
                }
                .tag(0)
            
            // 2. Список покупок (ПРОМЕЖУТОЧНЫЙ ЭКРАН)
            ShoppingListView()  // 👈 ВАЖНО: именно здесь!
                .tabItem {
                    Label("Список", systemImage: "cart")  // Меняем "Корзина" на "Список"
                }
                .tag(1)  // 👈 Добавляем tag 1
            
            // 3. Добавить рецепт
            AddRecipeView()
                .tabItem {
                    Label("Добавить", systemImage: "plus.circle")
                }
                .tag(2)
            
            // 4. Избранное
            FavoritesView()
                .tabItem {
                    Label("Избранное", systemImage: "heart")
                }
                .tag(3)
        }
        .tint(.primary)
        .overlay(alignment: .bottom) {
            if let error = bootstrapError {
                bootstrapErrorView(error)
            }
        }
    }
    
    // MARK: - Splash
    
    private var splashView: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 22) {

                Spacer()

                Image("mouse_shef")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200)
                    .position(x:220, y: 290)

                Text("Привет от Реми")
                    .font(.system(size: 36, weight: .bold))
                    .multilineTextAlignment(.center)
                    .position(x: 225, y: 200)

                Text("Кулинарные рецепты")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .position(x: 225, y: 200)

                ProgressView()
                    .padding(.top, 12)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Bootstrap Error View
    
    private func bootstrapErrorView(_ error: String) -> some View {
        Text(error)
            .font(.caption)
            .foregroundStyle(.red)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.regularMaterial)
            .clipShape(Capsule())
            .padding(.bottom, 6)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    // MARK: - Bootstrap
    
    private func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true
        
        let minimumSplashTime: TimeInterval = 1.5
        let startTime = Date()
        
        DispatchQueue.global(qos: .userInitiated).async {
            
            // Если нужно что-то инициализировать — делай здесь
            
            let elapsed = Date().timeIntervalSince(startTime)
            let remaining = max(0, minimumSplashTime - elapsed)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + remaining) {
                withAnimation(.easeOut(duration: 0.4)) {
                    showSplash = false
                }
            }
        }
    }
}
