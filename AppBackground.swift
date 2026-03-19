import SwiftUI

enum AppBackgroundMode {
    case home
    case list
    case detail
    case search
    
    var gradientOpacity: Double {
        switch self {
        case .home: return 0.2
        case .list: return 0.3
        case .detail: return 0.4
        case .search: return 0.25
        }
    }
    
    var secondaryOpacity: Double {
        switch self {
        case .home: return 0.3
        case .list: return 0.4
        case .detail: return 0.5
        case .search: return 0.35
        }
    }
}

struct AppBackground: View {
    // MARK: - Properties
    
    let mode: AppBackgroundMode
    let showGradient: Bool
    let showImage: Bool
    
    // MARK: - Init
    
    init(
        _ mode: AppBackgroundMode = .home,
        showGradient: Bool = true,
        showImage: Bool = true
    ) {
        self.mode = mode
        self.showGradient = showGradient
        self.showImage = showImage
    }
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Базовый цвет фона (всегда есть)
                backgroundColor
                    .ignoresSafeArea()
                
                // Волны (опционально)
                if showImage {
                    wavesView
                        .ignoresSafeArea()
                }
                
                // Градиент (опционально)
                if showGradient {
                    gradientView
                        .ignoresSafeArea()
                }
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Background Color
    
    private var backgroundColor: some View {
        Color(.systemBackground)
    }
    
    // MARK: - Waves
    
    private var wavesView: some View {
        Image("bg_wave_top")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .clipped()
            .saturation(0.7)        // уменьшаем насыщенность
            .brightness(-0.05)       // немного затемняем
            .contrast(0.85)          // уменьшаем контраст
            .opacity(0.35)           // делаем полупрозрачным
            .overlay(
                Color(.systemBackground).opacity(0.15)
                    .blendMode(.overlay)
            )
    }
    
    // MARK: - Gradient
    
    private var gradientView: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground).opacity(mode.gradientOpacity),
                Color(.systemGray6).opacity(mode.secondaryOpacity)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Alternative Backgrounds

struct SolidBackground: View {
    var body: some View {
        Color(.systemBackground)
            .ignoresSafeArea()
    }
}

struct GradientBackground: View {
    let topColor: Color
    let bottomColor: Color
    
    init(
        topColor: Color = Color(.systemBackground),
        bottomColor: Color = Color(.systemGray6)
    ) {
        self.topColor = topColor
        self.bottomColor = bottomColor
    }
    
    var body: some View {
        LinearGradient(
            colors: [topColor, bottomColor],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        // Режимы
        Group {
            Text("Home mode")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            ZStack {
                AppBackground(.home)
                
                Text("Контент")
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
            .padding(.bottom)
            
            Text("List mode")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            ZStack {
                AppBackground(.list)
                
                Text("Контент")
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
            .padding(.bottom)
            
            Text("Detail mode")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            ZStack {
                AppBackground(.detail)
                
                Text("Контент")
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
            .padding(.bottom)
            
            Text("Search mode")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            ZStack {
                AppBackground(.search)
                
                Text("Контент")
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
            .padding(.bottom)
        }
        
        // Без картинки
        Group {
            Text("Without waves")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            ZStack {
                AppBackground(showImage: false)
                
                Text("Контент")
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
            .padding(.bottom)
        }
        
        // Без градиента
        Group {
            Text("Without gradient")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            ZStack {
                AppBackground(showGradient: false)
                
                Text("Контент")
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }
    .padding(.vertical)
}
