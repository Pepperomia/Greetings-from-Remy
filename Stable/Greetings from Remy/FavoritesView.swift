import SwiftUI

struct FavoritesView: View {

    private enum Constants {
        static let headerSidePadding: CGFloat = 20
    }

    @State private var items: [RecipeRow] = []
    @State private var showAddCategory = false

    var body: some View {

        NavigationStack {

            ZStack {

                AppBackground(.list)

                ScrollView {

                    VStack(spacing: 20) {

                        header

                        if items.isEmpty {

                            Text("Пока нет избранных рецептов")
                                .padding(.top, 40)
                                .foregroundStyle(.secondary)

                        } else {

                            list
                        }
                    }
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Избранное")
            .navigationBarTitleDisplayMode(.inline)

            .toolbar {

                ToolbarItem(placement: .topBarTrailing) {

                    Button {
                        showAddCategory = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }

            .sheet(isPresented: $showAddCategory) {

                AddCategorySheet {
                    load()
                }
            }
        }

        .onAppear {
            load()
        }
    }

    // MARK: HEADER

    private var header: some View {

        HStack(spacing: 16) {

            Image(systemName: "heart.fill")
                .font(.system(size: 40))
                .foregroundStyle(.pink)

            VStack(alignment: .leading) {

                Text("Избранное")
                    .font(.title3.bold())

                if !items.isEmpty {

                    Text("\(items.count) рецептов")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, Constants.headerSidePadding)
        .padding(.top, 10)
    }

    // MARK: LIST

    private var list: some View {

        LazyVStack(spacing: 12) {

            ForEach(items) { recipe in

                NavigationLink {

                    RecipeDetailView(recipeId: recipe.id)

                } label: {

                    HStack {

                        VStack(alignment: .leading, spacing: 6) {

                            Text(recipe.title)
                                .font(.headline)

                            HStack(spacing: 8) {

                                Text(recipe.timeText)
                                    .font(.subheadline)

                                if !recipe.timeText.isEmpty && !recipe.difficultyText.isEmpty {

                                    Text("•")
                                        .foregroundStyle(.secondary)
                                }

                                Text(recipe.difficultyText)
                                    .font(.subheadline)
                            }
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()

                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.regularMaterial)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Constants.headerSidePadding)
            }
        }
    }

    // MARK: DATA

    private func load() {

        // пока избранное не подключено к БД
        items = []
    }
}

#Preview {
    FavoritesView()
}
