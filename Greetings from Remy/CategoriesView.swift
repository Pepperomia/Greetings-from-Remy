import SwiftUI
import UIKit

struct CategoriesView: View {
    @State private var items: [CategoryRow] = []
    @State private var errorText: String?
    @State private var showSearch = false

    var body: some View {
        NavigationStack {
            ZStack {
                // База: белый низ + верхняя волна (как в AppBackground)
                AppBackground(.home)

                // Мягкий “подфон” за карточками: размытая волна на весь экран, очень деликатно
                Image("bg_wave_top")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .blur(radius: 30)
                    .opacity(0.10)

                // Лёгкая вуаль, но НЕ такая плотная как 0.55 (она убивает фон)
                Color.white
                    .opacity(0.72)
                    .ignoresSafeArea()

                // Контент
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {

                        // Поиск
                        Button { showSearch = true } label: {
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
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(items) { item in
                                    NavigationLink {
                                        RecipesListView(category: item)
                                    } label: {
                                        let meta = cardMeta(for: item.name, count: item.count)

                                        CategoryCardRow(
                                            title: displayTitle(for: item.name),
                                            subtitle: meta.subtitle,
                                            imageName: meta.imageName
                                        )
                                        .padding(.horizontal)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.top, 6)
                            .padding(.bottom, 28)
                        }
                    }
                }
            }
            .navigationTitle("Каталог")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showSearch) {
                SearchView()
            }
            .onAppear { load() }
        }
    }

    // MARK: - Data

    private func load() {
        do {
            errorText = nil
            items = try DatabaseManager.shared.fetchCategories()
        } catch {
            errorText = error.localizedDescription
            items = []
        }
    }

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

    // MARK: - UI

    private struct CategoryCardRow: View {
        let title: String
        let subtitle: String
        let imageName: String?

        private let imageSize: CGFloat = 170

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
                        .offset(x: 6, y: -2)
                } else {
                    Color.clear
                        .frame(width: imageSize, height: imageSize)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 10)
        }
    }
}
