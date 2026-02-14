import SwiftUI
import UIKit

struct CategoriesView: View {
    @State private var items: [CategoryRow] = []
    @State private var errorText: String?
    @State private var showSearch = false
    @State private var isSearchExpanded = false

    // Одна точка управления размером картинок
    private let cardImageSize: CGFloat = 190

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground(.home)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        // MARK: - Кастомный заголовок
                        HStack(alignment: .center, spacing: 16) {
                            Image("mouse_book")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 160)   // было 80 → стало в 2 раза больше

                            Text("Каталог")
                                .font(.headline.bold())

                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)

                        // Поиск
                        Button { showSearch = true } label: {
                            // ====== Поиск (мышь -> раскрыть поле) ======
                            HStack(spacing: 12) {

                                if isSearchExpanded {
                                    // Поле-плашка (тап -> SearchView)
                                    Button { showSearch = true } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: "magnifyingglass")
                                                .foregroundStyle(.secondary)

                                            Text("Найди рецепт")
                                                .foregroundStyle(.secondary)

                                            Spacer()
                                        }
                                        .padding(.vertical, 9)
                                        .padding(.horizontal, 14)
                                        .background(.thinMaterial)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(.white.opacity(0.18), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    // Кнопка “свернуть”
                                    Button {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                            isSearchExpanded = false
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(.secondary.opacity(0.75))
                                    }
                                    .buttonStyle(.plain)

                                } else {
                                    Spacer()

                                    // Мышь справа
                                    Button {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                            isSearchExpanded = true
                                        }
                                    } label: {
                                        Image("mouse_search")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 74, height: 74)   // ← тут размер мыши
                                            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)

                        if let errorText {
                            Text("Ошибка: \(errorText)")
                                .padding()
                                .background(.thinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .padding(.horizontal)
                                .padding(.top, 6)
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(items) { item in
                                    NavigationLink {
                                        RecipesListView(category: item)
                                    } label: {
                                        let meta = cardMeta(for: item.name, count: item.count)

                                        CategoryCardRow(
                                            title: item.name, // item.name уже нормализован в load()
                                            subtitle: meta.subtitle,
                                            imageName: meta.imageName,
                                            imageSize: cardImageSize
                                        )
                                        .frame(height: cardImageSize + 20)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.top, 6)
                            .padding(.bottom, 28)
                        }
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .tabBar)
            .navigationDestination(isPresented: $showSearch) {
                SearchView()
            }
            .onAppear { load() }
        }
    }
    private let categoryOrder: [String] = [
        "Завтраки", "Салаты", "Супы",
        "Горячее", "Гарниры",
        "Выпечка", "Закуски", "Десерты", "Напитки"
    ]

    // MARK: - Data

    private func load() {
        do {
            errorText = nil
            let raw = try DatabaseManager.shared.fetchCategories()

            // 1) нормализуем названия (Горячее/Гарниры)
            // 2) группируем по нормализованному названию, суммируем count — чтобы не было дублей
            let grouped = Dictionary(grouping: raw) { displayTitle(for: $0.name) }

            items = grouped.map { key, value in
                // ВАЖНО: оставляем id первой записи, имя — ключ группы, count суммируем
                CategoryRow(
                    id: value.first!.id,
                    name: key,
                    count: value.reduce(0) { $0 + $1.count }
                )
            }
            .sorted { a, b in
                let ia = categoryOrder.firstIndex(of: a.name) ?? 999
                let ib = categoryOrder.firstIndex(of: b.name) ?? 999
                return ia < ib
            }

        } catch {
            errorText = error.localizedDescription
            items = []
        }
    }

    /// “Железно” красиво отображаем, не трогая базу
    private func displayTitle(for raw: String) -> String {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if name == "Горячее (основное)" { return "Горячее" }
        if name == "Горячее (гарниры)" { return "Гарниры" }
        return name
    }

    private func cardMeta(for categoryName: String, count: Int) -> (subtitle: String, imageName: String?) {
        let name = displayTitle(for: categoryName)

        switch name {
        case "Завтраки":
            return ("• \(count) рецептов", "cat_breakfasts")
        case "Салаты":
            return ("• \(count) рецептов", "cat_salads")
        case "Супы":
            return ("• \(count) рецептов", "cat_soups")
        case "Горячее":
            return ("• \(count) рецептов", "cat_mains")
        case "Гарниры":
            return ("• \(count) рецептов", "cat_sides")
        case "Выпечка":
            return ("• \(count) рецептов", "cat_bakery")
        case "Закуски":
            return ("• \(count) рецептов", "cat_snacks")
        case "Десерты":
            return ("• \(count) рецептов", "cat_desserts")
        case "Напитки":
            return ("• \(count) рецептов", "cat_drinks")
        default:
            return ("\(count) рецептов", nil)
        }
    }

    // MARK: - UI

    private struct CategoryCardRow: View {
        let title: String
        let subtitle: String
        let imageName: String?
        let imageSize: CGFloat

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
                        .offset(x: 10, y: -4)
                } else {
                    Color.clear
                        .frame(width: imageSize, height: imageSize)
                }
            }
            // плашка ниже по высоте
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.96) // влияет только на подложку
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.20), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 8)
        }
    }
}
