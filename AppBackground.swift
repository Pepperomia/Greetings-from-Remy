import SwiftUI

enum AppBackgroundMode {
    case home, list, detail
}

struct AppBackground: View {
    let mode: AppBackgroundMode

    init(_ mode: AppBackgroundMode = .home) {
        self.mode = mode
    }

    // Один фон для всех, позже можно сделать разные
    private var imageName: String { "bg_wave_top" }

    // Высота “шапки”
    private var topHeight: CGFloat { 260 }

    var body: some View {
        ZStack(alignment: .top) {
            // Нижняя база (чтобы внизу всегда было чисто)
            Color.white
                .ignoresSafeArea()

            // Верхняя волна (не растягиваем на весь экран!)
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: topHeight)
                .clipped()
                .ignoresSafeArea(edges: .top)
        }
    }
}
