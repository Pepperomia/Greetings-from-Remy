import SwiftUI

struct AddCategorySheet: View {
    let onCategoryAdded: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var categoryName = ""
    @State private var isSaving = false
    @State private var errorText: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Новая категория") {
                    TextField("Название категории", text: $categoryName)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.words)
                }
                
                if let errorText = errorText {
                    Section {
                        Text(errorText)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Добавить категорию")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        saveCategory()
                    }
                    .disabled(categoryName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
        .presentationDetents([.height(250)])
    }
    
    private func saveCategory() {
        let trimmedName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        isSaving = true
        errorText = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                _ = try DatabaseManager.shared.addCategory(name: trimmedName)
                
                DispatchQueue.main.async {
                    isSaving = false
                    onCategoryAdded()
                    dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    errorText = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}

#Preview {
    AddCategorySheet(onCategoryAdded: {})
}
