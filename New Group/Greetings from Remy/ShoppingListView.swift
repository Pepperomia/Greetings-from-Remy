import SwiftUI

struct ShoppingListView: View {

    @State private var items: [ShoppingItem] = []

    var body: some View {

        ZStack {

            AppBackground(.list)

            ScrollView {

                VStack(spacing: 20) {

                    headerView

                    listCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            load()
        }
    }

    // MARK: HEADER

    private var headerView: some View {

        HStack(alignment: .center, spacing: 25) {

            Image("mouse_shop")
                .resizable()
                .scaledToFit()
                .frame(width: 130, height: 130)
                .padding(.leading, 10)
                .fixedSize()

            VStack(alignment: .leading, spacing: 4) {

                Text("Список покупок")
                    .font(.title2)

                Text("\(items.count) товаров")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: CARD

    private var listCard: some View {

        GlassCard(radius: 28, opacity: 0.35, hasShadow: true, hasStroke: true) {

            LazyVStack(spacing: 0) {

                ForEach(items) { item in

                    row(item)
                        .contextMenu {

                            Button(role: .destructive) {
                                deleteItem(item)
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }

                    if item.id != items.last?.id {

                        Divider()
                            .opacity(0.25)
                            .padding(.leading, 56)
                    }
                }
            }
        }
    }

    // MARK: ROW

    private func row(_ item: ShoppingItem) -> some View {

        HStack(spacing: 14) {

            Image(systemName: item.isChecked ? "checkmark.square.fill" : "square")
                .font(.title3)
                .foregroundStyle(item.isChecked ? .green : .gray)
                .frame(width: 26)
                .onTapGesture {
                    withAnimation(.easeInOut) {
                        toggle(item)
                        load()
                    }
                }

            Text(item.name)
                .font(.body)
                .strikethrough(item.isChecked)

            Spacer()

            if let amount = item.amountText, !amount.isEmpty {

                Text(amount)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .strikethrough(item.isChecked)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .opacity(item.isChecked ? 0.6 : 1)
    }

    // MARK: DATA

    private func load() {
        items = (try? DatabaseManager.shared.fetchShoppingList()) ?? []
    }

    private func toggle(_ item: ShoppingItem) {
        try? DatabaseManager.shared.toggleShoppingItem(id: item.id)
        load()
    }

    private func deleteItem(_ item: ShoppingItem) {
        try? DatabaseManager.shared.deleteShoppingItem(id: item.id)
        load()
    }
}
