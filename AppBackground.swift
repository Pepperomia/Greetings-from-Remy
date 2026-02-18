import SwiftUI

enum AppBackgroundMode {
    case home, list, detail
}

struct AppBackground: View {
    let mode: AppBackgroundMode

    init(_ mode: AppBackgroundMode = .home) {
        self.mode = mode
    }

    private var imageName: String { "bg_wave_top" }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1) Базовый фон на весь экран
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                
                // 2) Градиент поверх
                LinearGradient(
                    colors: [
                        Color(.systemBackground).opacity(0.3),
                        Color(.systemGray6).opacity(0.4)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}
