import SwiftUI
import UIKit

struct RootView: View {
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemThinMaterial)
        appearance.backgroundColor = UIColor.white.withAlphaComponent(0.12)

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            CategoriesView()
                .tabItem { Label("Каталог", systemImage: "square.grid.2x2") }

            AddRecipeView()
                .tabItem { Label("Добавить", systemImage: "plus.circle") }

            FavoritesView()
                .tabItem { Label("Избранное", systemImage: "heart") }
        }
    }
}
