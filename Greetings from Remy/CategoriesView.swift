import SwiftUI

struct CategoriesView: View {
    @State private var items: [CategoryRow] = []
    @State private var errorText: String?
    @State private var showSearch = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground(.home)

                VStack(spacing: 12) {

                    // Поиск (тап -> SearchView)
                    Button {
                        showSearch = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)

                            Text("Найди рецепт")
                                .foregroundStyle(.secondary)

                            Spacer()

                            Image(systemName: "mic.fill")
                                .foregroundStyle(.secondary.opacity(0.75))
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)

                    if let errorText {
                        Text("Ошибка: \(errorText)")
                            .padding()
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                        Spacer()
                    } else {
                        List {
                            ForEach(items) { item in
                                NavigationLink {
                                    RecipesListView(category: item)
                                } label: {
                                    let meta = cardMeta(for: item.name, count: item.count)
                                    CategoryCardRow(
                                        title: item.name,
                                        subtitle: meta.subtitle,
                                        imageName: meta.imageName
                                    )
                                }
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .padding(.top, 2)
                    }
                }
            }
            .navigationTitle("Каталог")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(isPresented: $showSearch) {
                SearchView()
            }
            .onAppear { load() }
        }
    }

    private func load() {
        do {
            errorText = nil
            items = try DatabaseManager.shared.fetchCategories()
        } catch {
            errorText = error.localizedDescription
            items = []
        }
    }

    // Подписи + картинки по категориям
    private func cardMeta(for categoryName: String, count: Int) -> (subtitle: String, imageName: String?) {
        let name = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)

        switch name {
        case "Завтраки":
            return ("Быстрый старт дня • \(count) рецептов", "cat_breakfasts")
        case "Салаты":
            return ("Свежие и сытные • \(count) рецептов", "cat_salads")
        case "Супы":
            return ("Тёплые и уютные • \(count) рецептов", "cat_soups")
        case "Горячее":
            return ("Главные блюда • \(count) рецептов", "cat_mains")
        case "Гарниры":
            return ("К любому основному • \(count) рецептов", "cat_sides")
        case "Выпечка":
            return ("Домашняя и ароматная • \(count) рецептов", "cat_bakery")
        case "Закуски":
            return ("Перекус и стол • \(count) рецептов", "cat_snacks")
        case "Десерты":
            return ("Сладкое настроение • \(count) рецептов", "cat_desserts")
        case "Напитки":
            return ("Тёплое и холодное • \(count) рецептов", "cat_drinks")
        default:
            return ("\(count) рецептов", nil)
        }
    }

    // Локальная карточка строки (не конфликтует с другими файлами)
    private struct CategoryCardRow: View {
        let title: String
        let subtitle: String
        let imageName: String?

        private let imageSize: CGFloat = 150  // большие картинки

        var body: some View {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                if let imageName, !imageName.isEmpty, UIImage(named: imageName) != nil {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: imageSize, height: imageSize)
                        .padding(.trailing, 2)
                } else {
                    Color.clear
                        .frame(width: imageSize, height: imageSize)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(.white.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 10)
        }
    }
}
