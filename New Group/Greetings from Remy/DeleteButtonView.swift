import SwiftUI

struct DeleteButtonView: View {
    let title: String
    let message: String
    let onDelete: () throws -> Void
    @Binding var errorText: String?
    
    @State private var showingAlert = false
    @State private var isDeleting = false
    
    var body: some View {
        Button(role: .destructive) {
            showingAlert = true
        } label: {
            HStack {
                if isDeleting {
                    ProgressView()
                        .tint(.red)
                } else {
                    Image(systemName: "trash")
                }
                Text(title)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.regularMaterial)
            .foregroundColor(.red)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(isDeleting)
        .alert("Подтверждение", isPresented: $showingAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Удалить", role: .destructive) {
                performDelete()
            }
        } message: {
            Text(message)
        }
    }
    
    private func performDelete() {
        isDeleting = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try onDelete()
                
                DispatchQueue.main.async {
                    isDeleting = false
                    showingAlert = false
                }
            } catch {
                DispatchQueue.main.async {
                    errorText = error.localizedDescription
                    isDeleting = false
                }
            }
        }
    }
}
