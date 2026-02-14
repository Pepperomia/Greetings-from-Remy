import SwiftUI

enum AppBackgroundMode {
    case home, list, detail
}

struct AppBackground: View {
    let mode: AppBackgroundMode

    init(_ mode: AppBackgroundMode = .home) {
        self.mode = mode
    }

    // Один фон для всех (позже можно сделать разные)
    private var imageName: String { "bg_wave_top" }

    var body: some View {
        ZStack {
            // База, чтобы не было “дыр”
            Color.white.ignoresSafeArea()

            // Фон на весь экран
            Image(imageName)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // “Молочная” вуаль: сверху меньше, снизу больше (для читаемости карточек)
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.10), location: 0.00),
                    .init(color: .white.opacity(0.35), location: 0.30),
                    .init(color: .white.opacity(0.75), location: 0.70),
                    .init(color: .white.opacity(0.92), location: 1.00),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}
