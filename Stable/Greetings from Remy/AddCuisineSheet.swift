import SwiftUI

struct AddCuisineSheet: View {
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @State private var name = ""
    @State private var errorText: String?
    @State private var isAdding = false
    
    // MARK: - Properties
    
    let onAdded: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                
                content
            }
            .navigationTitle("Новая кухня")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    cancelButton
                }
                ToolbarItem(placement: .confirmationAction) {
                    addButton
                }
            }
        }
    }
    
    // MARK: - Content
    
    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                inputCard
                
                if let errorText = errorText {
                    errorCard(errorText)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Input Card
    
    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Название кухни")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            TextField("например: Грузинская", text: $name)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.regularMaterial)
                .cornerRadius(8)
                .disabled(isAdding)
        }
        .padding(16)
        .glassCard()
    }
    
    // MARK: - Error Card
    
    private func errorCard(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.red)
            
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Buttons
    
    private var cancelButton: some View {
        Button("Отмена") {
            dismiss()
        }
    }
    
    private var addButton: some View {
        Button(action: add) {
            if isAdding {
                ProgressView()
                    .tint(.primary)
            } else {
                Text("Добавить")
                    .bold()
            }
        }
        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAdding)
    }
    
    // MARK: - Actions
    
    private func add() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        isAdding = true
        errorText = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                _ = try DatabaseManager.shared.addCuisine(name: trimmedName)
                
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

// MARK: - Preview

#Preview {
    AddCuisineSheet(onAdded: {})
}
