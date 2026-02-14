import SwiftUI

enum AppBackgroundMode {
    case home
    case list
    case detail
}

struct AppBackground: View {
    let mode: AppBackgroundMode

    init(_ mode: AppBackgroundMode = .home) {
        self.mode = mode
    }

    private var imageName: String {
        // Используем тот фон, который у тебя точно есть в Assets
        return "bg_wave_top"
    }

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 240)
                    .clipped()

                Spacer()
            }
            .ignoresSafeArea()
        }
    }
}
