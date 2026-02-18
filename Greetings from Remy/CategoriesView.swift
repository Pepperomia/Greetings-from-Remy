import SwiftUI
import UIKit

struct CategoriesView: View {
    @State private var items: [CategoryRow] = []
    @State private var errorText: String?
    @State private var showSearch = false

    // Мышь вместо поиска
    @State private var isSearchExpanded = false

    // Размер картинок в карточках категорий
    private let cardImageSize: CGFloat = 200

    // Одна точка управления UI
    private enum UI {
        static let mouseBookSize: CGFloat = 150      // размер мыши у "Каталог"
        static let mouseSearchSize: CGFloat = 100    // размер мыши поиска
        static let headerTopPadding: CGFloat = 10
        static let headerSidePadding: CGFloat = 20
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground(.home)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {

                        headerSection

                        if let errorText {
                            errorView(errorText)
                        } else {
                            categoriesGrid
                        }
                    }
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .tabBar)
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showSearch) {
                SearchView()
            }
            .onAppear { load() }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // Заголовок с мышью
            HStack(spacing: 12) {
                MouseSticker("mouse_book", size: UI.mouseBookSize)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Каталог")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.primary)
                    
                    Text("\(items.count) категорий")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, UI.headerSidePadding)
            .padding(.top, UI.headerTopPadding)

            // Поисковая строка
            searchRow
                .padding(.horizontal, UI.headerSidePadding)
        }
    }

    // MARK: - Search Row

    private var searchRow: some View {
        HStack(spacing: 12) {
            if isSearchExpanded {
                // Раскрытый поиск
                Button { showSearch = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text("Найди рецепт по ингредиентам...")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Spacer()

                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 18)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        isSearchExpanded = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .background(
                            Circle()
                                .fill(.regularMaterial)
                                .frame(width: 40, height: 40)
                        )
                }
                .buttonStyle(.plain)

            } else {
                // Свернутый поиск - только мышь
                Spacer()

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        isSearchExpanded = true
                    }
                } label: {
                    MouseSticker("mouse_search", size: UI.mouseSearchSize)
                        .background(
                            Circle()
                                .fill(.regularMaterial)
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Categories Grid

    private var categoriesGrid: some View {
        LazyVGrid(columns: [GridItem(.fixed(180), spacing: 16), GridItem(.fixed(180), spacing: 16)], spacing: 16) {
            ForEach(items) { item in
                NavigationLink {
                    RecipesListView(category: item)
                } label: {
                    categoryCard(item)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, UI.headerSidePadding)
        .padding(.top, 8)
    }

    private func categoryCard(_ item: CategoryRow) -> some View {
        let cardMetaData = cardMeta(for: item.name, count: item.count)
        
        return VStack(alignment: .leading, spacing: 8) {
            // Изображение категории
            if let imageName = cardMetaData.imageName {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
                    .frame(height: 120)
                    .overlay(
                        Image(systemName: "fork.knife")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle(for: item.name))
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text(cardMetaData.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: 32) // ← ФИКСИРОВАННАЯ ВЫСОТА ДЛЯ ТЕКСТА
            }
            .padding(.horizontal, 4)
        }
        .padding(8)
        .frame(height: 200) // ← ФИКСИРОВАННАЯ ВЫСОТА ВСЕЙ КАРТОЧКИ
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }
    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            Text("Ошибка: \(error)")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, UI.headerSidePadding)
    }

    // MARK: - Data
    private let categoryOrder: [String] = [
        "Завтраки",
        "Салаты",
        "Супы",
        "Горячее",
        "Гарниры",
        "Выпечка",
        "Закуски",
        "Десерты",
        "Напитки"
    ]
    
    private func load() {
        do {
            errorText = nil
            let raw = try DatabaseManager.shared.fetchCategories()

            // Убираем визуальные дубли по отображаемому названию
            let grouped = Dictionary(grouping: raw) { displayTitle(for: $0.name) }

            var deduped: [CategoryRow] = []
            deduped.reserveCapacity(grouped.count)

            for (key, value) in grouped {
                if let best = value.max(by: { $0.count < $1.count }) {
                    deduped.append(CategoryRow(id: best.id, name: key, count: best.count))
                }
            }

            let orderIndex: [String: Int] = Dictionary(
                uniqueKeysWithValues: categoryOrder.enumerated().map { ($0.element, $0.offset) }
            )

            items = deduped.sorted { a, b in
                let ia = orderIndex[a.name] ?? Int.max
                let ib = orderIndex[b.name] ?? Int.max
                if ia != ib { return ia < ib }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }

        } catch {
            errorText = error.localizedDescription
            items = []
        }
    }

    // MARK: - Mapping / UI copy

    private func displayTitle(for raw: String) -> String {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if name == "Горячее (основное)" { return "Горячее" }
        if name == "Горячее (гарниры)" { return "Гарниры" }
        return name
    }

    private func cardMeta(for categoryName: String, count: Int) -> (subtitle: String, imageName: String?) {
        let name = displayTitle(for: categoryName)
        let countText = "\(count) \(pluralize(count: count))"

        switch name {
        case "Завтраки":
            return ("Быстрый старт дня • \(countText)", "cat_breakfasts")
        case "Салаты":
            return ("Свежие и сытные • \(countText)", "cat_salads")
        case "Супы":
            return ("Тёплые и уютные • \(countText)", "cat_soups")
        case "Горячее":
            return ("Главные блюда • \(countText)", "cat_mains")
        case "Гарниры":
            return ("К любому основному • \(countText)", "cat_sides")
        case "Выпечка":
            return ("Домашняя и ароматная • \(countText)", "cat_bakery")
        case "Закуски":
            return ("Перекус и стол • \(countText)", "cat_snacks")
        case "Десерты":
            return ("Сладкое настроение • \(countText)", "cat_desserts")
        case "Напитки":
            return ("Тёплое и холодное • \(countText)", "cat_drinks")
        default:
            return ("\(countText)", nil)
        }
    }
    
    private func pluralize(count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        
        if mod10 == 1 && mod100 != 11 {
            return "рецепт"
        } else if mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20) {
            return "рецепта"
        } else {
            return "рецептов"
        }
    }
}

// MARK: - Mouse sticker helper
private struct MouseSticker: View {
    let name: String
    let size: CGFloat

    init(_ name: String, size: CGFloat) {
        self.name = name
        self.size = size
    }

    var body: some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
