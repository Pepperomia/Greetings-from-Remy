import SwiftUI

enum AppBackgroundMode {
    case home
    case list
    case detail
    case search

    var gradientOpacity: Double {
        switch self {
        case .home: return 0.15
        case .list: return 0.22
        case .detail: return 0.28
        case .search: return 0.18
        }
    }

    var secondaryOpacity: Double {
        switch self {
        case .home: return 0.25
        case .list: return 0.30
        case .detail: return 0.35
        case .search: return 0.28
        }
    }
}

struct AppBackground: View {

    let mode: AppBackgroundMode
    let showGradient: Bool
    let showImage: Bool

    @State private var glow = false

    init(
        _ mode: AppBackgroundMode = .home,
        showGradient: Bool = true,
        showImage: Bool = true
    ) {
        self.mode = mode
        self.showGradient = showGradient
        self.showImage = showImage
    }

    var body: some View {

        ZStack {

            backgroundColor

            if showImage {
                wavesView
            }

            if showGradient {
                gradientView
            }

            glowLayer
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(
                .easeInOut(duration: 8)
                .repeatForever(autoreverses: true)
            ) {
                glow.toggle()
            }
        }
    }

    private var backgroundColor: some View {
        Color(.systemBackground)
    }

    private var wavesView: some View {
        Image("bg_wave_top")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .ignoresSafeArea()
            .saturation(0.65)
            .brightness(-0.04)
            .contrast(0.9)
            .opacity(0.32)
            .overlay(
                Color(.systemBackground)
                    .opacity(0.18)
                    .blendMode(.overlay)
            )
    }

    private var gradientView: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground)
                    .opacity(mode.gradientOpacity),

                Color(.systemGray6)
                    .opacity(mode.secondaryOpacity)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var glowLayer: some View {

        RadialGradient(
            colors: [
                Color.orange.opacity(glow ? 0.08 : 0.02),
                Color.clear
            ],
            center: .topLeading,
            startRadius: 100,
            endRadius: 500
        )
        .blendMode(.softLight)
    }
}
