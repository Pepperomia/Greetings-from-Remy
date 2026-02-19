import SwiftUI

struct EditRecipeView: View {
    let recipeId: Int
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Редактирование") {
                    Text("Редактирование рецепта \(recipeId)")
                        .font(.headline)
                }
            }
            .navigationTitle("Редактировать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { dismiss() }
                }
            }
        }
    }
}
