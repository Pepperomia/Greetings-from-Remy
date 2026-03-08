import SwiftUI

struct FavoritesView: View {

    @State private var items: [RecipeRow] = []

    var body: some View {

        NavigationStack {

            GeometryReader { geo in

                ZStack {

                    AppBackground(.list)

                    // HEADER
                    VStack {

                        header

                        Spacer()
                    }
                    .padding(.top, geo.safeAreaInsets.top)

                    // TOP MOUSE
                    topMouse
                        .position(
                            x: 70,
                            y: geo.safeAreaInsets.top + 52
                        )

                    // CENTER TEXT
                    centerText
                        .position(
                            x: geo.size.width / 2,
                            y: geo.size.height / 2
                        )

                    // BOTTOM MOUSE
                    bottomMouse
                        .position(
                            x: geo.size.width / 2,
                            y: geo.size.height - geo.safeAreaInsets.bottom - 84
                        )
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            load()
        }
    }

    // MARK: HEADER

    private var header: some View {

        HStack {

            Text("Избранное")
                .font(.title2.bold())

            Spacer()
        }
        .padding(.horizontal, 124)
    }

    // MARK: TOP MOUSE

    private var topMouse: some View {

        Image("mouse_love")
            .resizable()
            .scaledToFit()
            .frame(width: 110)
    }

    // MARK: CENTER TEXT

    private var centerText: some View {

        VStack(spacing: 12) {

            Text("Пока пусто")
                .font(.headline)

            Text("Добавьте любимые рецепты")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: BOTTOM MOUSE

    private var bottomMouse: some View {

        Image("mouse_look")
            .resizable()
            .scaledToFit()
            .frame(width: 560)
    }

    // MARK: DATA

    private func load() {
        items = []
    }
}

#Preview {
    FavoritesView()
}
