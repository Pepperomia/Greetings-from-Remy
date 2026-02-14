import SwiftUI

enum WaveSegment: Int {
    case left = 0
    case middle = 1
    case right = 2
}

struct WaveStripBackground: View {
    let imageName: String
    let segment: WaveSegment

    var body: some View {
        GeometryReader { geo in
            // Мы показываем одну треть картинки.
            // Условие: исходный файл — это три экрана в ряд (ширина ~ в 3 раза больше высоты).
            Image(imageName)
                .resizable()
                .scaledToFill()
                // Делаем ширину в 3 раза больше экрана,
                // чтобы "триптих" лег точно в 3 экрана.
                .frame(width: geo.size.width * 3, height: geo.size.height)
                // Сдвигаем нужный сегмент в видимую область:
                // левый: 0, средний: -1 экран, правый: -2 экрана
                .offset(x: -geo.size.width * CGFloat(segment.rawValue))
                .clipped()
                .ignoresSafeArea()
        }
    }
}
