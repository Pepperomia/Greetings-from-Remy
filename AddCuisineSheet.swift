import SwiftUI

struct AddCuisineSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var errorText: String?

    let onAdded: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Новая кухня") {
                    TextField("Например: Грузинская", text: $name)
                }

                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Добавить кухню")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Добавить") { add() }
                }
            }
        }
    }

    private func add() {
        do {
            errorText = nil
            _ = try DatabaseManager.shared.addCuisine(name: name)
            onAdded()
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
