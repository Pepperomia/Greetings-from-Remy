import SwiftUI
import UIKit

struct CategoriesView: View {
    @State private var items: [CategoryRow] = []
    @State private var errorText: String?
    @State private var showSearch = false

    // Мышь вместо поиска
    @State private var isSearchExpanded = false

    // Размер картинок в карточках категорий (фиксируем)
    private let cardImageSize: CGFloat = 210

    // Одна точка управления UI
    private enum UI {
        static let mouseBookSize: CGFloat = 110      // <-- размер мыши у "Каталог"
        static let mouseSearchSize: CGFloat = 110    // <-- размер мыши поиска
        static let headerTopPadding: CGFloat = 10
        static let headerSidePadding: CGFloat = 16
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground(.home)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {

                        headerSearchRow

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
                                        CategoryCard(
                                            title: displayTitle(for: item.name),
                                            subtitle: meta.subtitle,
                                            imageName: meta.imageName,
                                            imageSize: cardImageSize
                                        )
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

    // MARK: - Header (мышь + поиск)

    private var headerSearchRow: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack(spacing: 12) {
                MouseSticker("mouse_book", size: UI.mouseBookSize)

                Text("Каталог")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, UI.headerSidePadding)
            .padding(.top, UI.headerTopPadding)

            HStack(spacing: 12) {
                if isSearchExpanded {
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

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            isSearchExpanded = true
                        }
                    } label: {
                        MouseSticker("mouse_search", size: UI.mouseSearchSize)
                            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, UI.headerSidePadding)
            .padding(.top, 2)
        }
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

            // Убираем визуальные дубли по отображаемому названию:
            // берём вариант с максимальным count (чтобы не выбрать "пустой дубль")
            let grouped = Dictionary(grouping: raw) { displayTitle(for: $0.name) }

            var deduped: [CategoryRow] = []
            deduped.reserveCapacity(grouped.count)

            for (key, value) in grouped {
                if let best = value.max(by: { $0.count < $1.count }) {
                    // ВАЖНО: не используем ?? 0 — из-за этого часто и вылезает UUID/Int конфликт
                    deduped.append(CategoryRow(id: best.id, name: key, count: best.count))
                }
            }

            // порядок: можно поменять на твой кастомный список, если нужно
            let orderIndex: [String: Int] = Dictionary(
                uniqueKeysWithValues: categoryOrder.enumerated().map { ($0.element, $0.offset) }
            )

            items = deduped.sorted { a, b in
                let ia = orderIndex[a.name] ?? Int.max
                let ib = orderIndex[b.name] ?? Int.max

                if ia != ib { return ia < ib }
                // если обе не из списка (или одинаковая позиция) — по алфавиту
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
}

// MARK: - Mouse sticker helper
// Ключевой момент: scaledToFill + clipped -> “съедает” прозрачные поля PNG и мышь реально становится больше.
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
            .scaledToFill()
            .frame(width: size, height: size)
            .clipped()
            .accessibilityHidden(true)
    }
}
