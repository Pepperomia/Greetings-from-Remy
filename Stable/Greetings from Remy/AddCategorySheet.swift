import SwiftUI

struct AddCategorySheet: View {

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var errorText: String?
    @State private var isAdding = false

    let onAdded: () -> Void

    var body: some View {

        NavigationStack {

            ZStack {

                AppBackground()

                ScrollView {

                    VStack(spacing: 20) {

                        inputCard

                        if let errorText {
                            errorCard(errorText)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Новая категория")
            .navigationBarTitleDisplayMode(.inline)

            .toolbar {

                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {

                    Button(action: addCategory) {

                        if isAdding {
                            ProgressView()
                        } else {
                            Text("Добавить")
                                .bold()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAdding)
                }
            }
        }
    }
}

// MARK: UI

private extension AddCategorySheet {

    var inputCard: some View {

        VStack(alignment: .leading, spacing: 12) {

            Text("Название категории")
                .font(.headline)
                .foregroundStyle(.secondary)

            TextField("например: Завтраки", text: $name)
                .textFieldStyle(.roundedBorder)
                .disabled(isAdding)
        }
        .padding()
        .glassCard()
    }

    func errorCard(_ text: String) -> some View {

        HStack {

            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)

            Text(text)
                .font(.caption)
                .foregroundStyle(.red)

            Spacer()
        }
        .padding()
        .glassCard()
    }
}

// MARK: LOGIC

private extension AddCategorySheet {

    func addCategory() {

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else { return }

        isAdding = true
        errorText = nil

        DispatchQueue.global(qos: .userInitiated).async {

            do {

                try DatabaseManager.shared.addCategory(name: trimmed)

                DispatchQueue.main.async {

                    onAdded()
                    dismiss()
                }

            } catch {

                DispatchQueue.main.async {

                    errorText = error.localizedDescription
                    isAdding = false
                }
            }
        }
    }
}
