import SwiftUI

struct CategoriesManagementView: View {
    @State private var categories: [CategoryRow] = []
    @State private var errorText: String?
    @State private var isLoading = false
    @State private var showingAddCategory = false
    @State private var newCategoryName = ""
    
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
                    } else if categories.isEmpty {
                        emptyView
                    } else {
                        categoriesList
                        
                        // Кнопка удаления внизу списка
                        DeleteSectionButton(
                            categories: categories,
                            onDelete: { category in
                                try DatabaseManager.shared.deleteCategory(id: category.id)
                                awaitLoadCategories()
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
        .navigationTitle("Управление категориями")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddCategory) {
            addCategorySheet
        }
        .onAppear {
            loadCategories()
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
            showingAddCategory = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Добавить категорию")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.regularMaterial)
            .foregroundColor(.mint)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Add Category Sheet
    
    private var addCategorySheet: some View {
        NavigationStack {
            Form {
                TextField("Название категории", text: $newCategoryName)
                    .textFieldStyle(.roundedBorder)
            }
            .navigationTitle("Новая категория")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        newCategoryName = ""
                        showingAddCategory = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        addCategory()
                    }
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.height(200)])
    }
    
    // MARK: - Categories List
    
    private var categoriesList: some View {
        LazyVStack(spacing: 12) {
            ForEach(categories) { category in
                categoryRow(category)
            }
        }
    }
    
    private func categoryRow(_ category: CategoryRow) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.headline)
                
                Text(category.countText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if category.count == 0 {
                Text("Можно удалить")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.regularMaterial)
                    )
            } else {
                Text("Используется")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.regularMaterial)
                    )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
    }
    
    // MARK: - Delete Section Button
    
    struct DeleteSectionButton: View {
        let categories: [CategoryRow]
        let onDelete: (CategoryRow) throws -> Void
        @Binding var errorText: String?
        
        @State private var showingDeleteSheet = false
        @State private var selectedCategory: CategoryRow?
        @State private var isDeleting = false
        
        var deletableCategories: [CategoryRow] {
            categories.filter { $0.count == 0 }
        }
        
        var body: some View {
            if !deletableCategories.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Удаление категорий")
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
                            Text("Удалить пустые категории")
                            Spacer()
                            Text("\(deletableCategories.count)")
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
                    ForEach(deletableCategories) { category in
                        HStack {
                            Text(category.name)
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(role: .destructive) {
                                selectedCategory = category
                                performDelete(category)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .navigationTitle("Удаление категорий")
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
        
        private func performDelete(_ category: CategoryRow) {
            isDeleting = true
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try onDelete(category)
                    
                    DispatchQueue.main.async {
                        isDeleting = false
                        if deletableCategories.isEmpty {
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
        Text("Нет категорий")
            .foregroundStyle(.secondary)
            .padding(.top, 40)
    }
    
    private func errorView(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.red)
            .padding(.top, 40)
    }
    
    // MARK: - Load Data
    
    private func loadCategories() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fetched = try DatabaseManager.shared.fetchCategories()
                
                DispatchQueue.main.async {
                    categories = fetched
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
    
    private func awaitLoadCategories() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            loadCategories()
        }
    }
    
    // MARK: - Add Category
    
    private func addCategory() {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                _ = try DatabaseManager.shared.addCategory(name: trimmed)
                
                DispatchQueue.main.async {
                    newCategoryName = ""
                    showingAddCategory = false
                    loadCategories()
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
        CategoriesManagementView()
    }
}
