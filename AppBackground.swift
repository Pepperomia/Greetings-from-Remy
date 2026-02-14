import SwiftUI

enum AppBackgroundMode {
    case home, list, detail
}

struct AppBackground: View {
    let mode: AppBackgroundMode

    init(_ mode: AppBackgroundMode = .home) {
        self.mode = mode
    }

    private var imageName: String { "bg_wave_top" } // или "bg_wave_top" — оставь то имя, которое реально есть в Assets

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1) Базовый фон на весь экран
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()


                    Spacer()
                }
                .ignoresSafeArea()
            }
        }
    }

