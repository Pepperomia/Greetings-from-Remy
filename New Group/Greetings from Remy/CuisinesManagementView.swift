import SwiftUI

struct CuisinesManagementView: View {
    @State private var cuisines: [CuisineRow] = []
    @State private var errorText: String?
    @State private var isLoading = false
    @State private var showingAddCuisine = false
    @State private var newCuisineName = ""
    
    var body: some View {
        ZStack {
            AppBackground(.list)
            
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Кнопка добавления
                    addButton
                    
                    if isLoading {
                        ProgressView()
                            .padding(.top, 40)
                    } else if let errorText {
                        errorView(errorText)
                    } else if cuisines.isEmpty {
                        emptyView
                    } else {
                        cuisinesList
                        
                        // Кнопка удаления внизу списка
                        DeleteSectionButton(
                            cuisines: cuisines,
                            onDelete: { cuisine in
                                try DatabaseManager.shared.deleteCuisine(id: cuisine.id)
                                awaitLoadCuisines()
                            },
                            errorText: $errorText
                        )
                        .padding(.top, 20)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Управление кухнями")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddCuisine) {
            addCuisineSheet
        }
        .onAppear {
            loadCuisines()
        }
        .alert("Ошибка", isPresented: .constant(errorText != nil)) {
            Button("OK") {
                errorText = nil
            }
        } message: {
            Text(errorText ?? "")
        }
    }
    
    // MARK: - Add Button
    
    private var addButton: some View {
        Button {
            showingAddCuisine = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Добавить кухню")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.regularMaterial)
            .foregroundColor(.mint)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Add Cuisine Sheet
    
    private var addCuisineSheet: some View {
        NavigationStack {
            Form {
                TextField("Название кухни", text: $newCuisineName)
                    .textFieldStyle(.roundedBorder)
            }
            .navigationTitle("Новая кухня")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        newCuisineName = ""
                        showingAddCuisine = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        addCuisine()
                    }
                    .disabled(newCuisineName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.height(200)])
    }
    
    // MARK: - Cuisines List
    
    private var cuisinesList: some View {
        LazyVStack(spacing: 12) {
            ForEach(cuisines) { cuisine in
                cuisineRow(cuisine)
            }
        }
    }
    
    private func cuisineRow(_ cuisine: CuisineRow) -> some View {
        HStack {
            Text(cuisine.name)
                .font(.headline)
            
            Spacer()
            
            // Просто показываем, что можно удалить (без кнопки в каждой строке)
            Text("Можно удалить")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(.regularMaterial)
                )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
    }
    
    // MARK: - Delete Section Button
    
    struct DeleteSectionButton: View {
        let cuisines: [CuisineRow]
        let onDelete: (CuisineRow) throws -> Void
        @Binding var errorText: String?
        
        @State private var showingDeleteSheet = false
        @State private var selectedCuisine: CuisineRow?
        @State private var isDeleting = false
        
        var body: some View {
            if !cuisines.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Удаление кухонь")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Button {
                        showingDeleteSheet = true
                    } label: {
                        HStack {
                            if isDeleting {
                                ProgressView()
                                    .tint(.red)
                            } else {
                                Image(systemName: "trash")
                            }
                            Text("Управление удалением")
                            Spacer()
                            Text("\(cuisines.count)")
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(.red.opacity(0.2))
                                )
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
                }
                .sheet(isPresented: $showingDeleteSheet) {
                    deleteSheet
                }
            }
        }
        
        private var deleteSheet: some View {
            NavigationStack {
                List {
                    ForEach(cuisines) { cuisine in
                        HStack {
                            Text(cuisine.name)
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(role: .destructive) {
                                selectedCuisine = cuisine
                                performDelete(cuisine)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .disabled(isDeleting)
                        }
                    }
                }
                .navigationTitle("Удаление кухонь")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Готово") {
                            showingDeleteSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        
        private func performDelete(_ cuisine: CuisineRow) {
            isDeleting = true
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try onDelete(cuisine)
                    
                    DispatchQueue.main.async {
                        isDeleting = false
                        // Обновляем список после удаления
                        if cuisines.isEmpty {
                            showingDeleteSheet = false
                        }
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
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        Text("Нет кухонь")
            .foregroundStyle(.secondary)
            .padding(.top, 40)
    }
    
    private func errorView(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.red)
            .padding(.top, 40)
    }
    
    // MARK: - Load Data
    
    private func loadCuisines() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fetched = try DatabaseManager.shared.fetchAllCuisines()
                
                DispatchQueue.main.async {
                    cuisines = fetched
                    isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    errorText = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func awaitLoadCuisines() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            loadCuisines()
        }
    }
    
    // MARK: - Add Cuisine
    
    private func addCuisine() {
        let trimmed = newCuisineName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                _ = try DatabaseManager.shared.addCuisine(name: trimmed)
                
                DispatchQueue.main.async {
                    newCuisineName = ""
                    showingAddCuisine = false
                    loadCuisines()
                }
            } catch {
                DispatchQueue.main.async {
                    errorText = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CuisinesManagementView()
    }
}
