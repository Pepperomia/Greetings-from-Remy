import SwiftUI

struct DeleteManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: DeleteType = .category
    @State private var selectedItemId: Int?
    @State private var showingConfirmAlert = false
    @State private var isDeleting = false
    @State private var errorText: String?
    
    // Данные
    @State private var categories: [CategoryRow] = []
    @State private var cuisines: [CuisineRow] = []
    
    enum DeleteType: String, CaseIterable {
        case category = "Категория"
        case cuisine = "Кухня"
        
        var icon: String {
            switch self {
            case .category: return "folder"
            case .cuisine: return "globe"
            }
        }
        
        var color: Color {
            switch self {
            case .category: return .blue
            case .cuisine: return .green
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground(.list)
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Переключатель типа
                        Picker("Тип", selection: $selectedType) {
                            ForEach(DeleteType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.top, 8)
                        
                        if let errorText {
                            errorView(errorText)
                        }
                        
                        // Выпадающий список
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Выберите элемент для удаления")
                                .font(.headline)
                            
                            Menu {
                                switch selectedType {
                                case .category:
                                    ForEach(categories) { category in
                                        Button(category.name) {
                                            selectedItemId = category.id
                                        }
                                    }
                                case .cuisine:
                                    ForEach(cuisines) { cuisine in
                                        Button(cuisine.name) {
                                            selectedItemId = cuisine.id
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedItemName)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                }
                                .padding()
                                .background(.regularMaterial)
                                .cornerRadius(12)
                            }
                            
                            // Информация об использовании
                            if let usageInfo = usageInfo {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundStyle(.secondary)
                                    Text(usageInfo)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.top, 4)
                            }
                            
                            // Кнопка удаления
                            Button(role: .destructive) {
                                if selectedItemId != nil {
                                    showingConfirmAlert = true
                                }
                            } label: {
                                HStack {
                                    if isDeleting {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "trash")
                                    }
                                    Text("Удалить")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(selectedItemId == nil ? Color.gray : Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(selectedItemId == nil || isDeleting)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(.regularMaterial)
                        )
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("Управление удалением")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .alert("Подтверждение удаления", isPresented: $showingConfirmAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Удалить", role: .destructive) {
                    performDelete()
                }
            } message: {
                Text(confirmMessage)
            }
            .onAppear {
                loadData()
            }
            .onChange(of: selectedType) { _, _ in
                selectedItemId = nil
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var selectedItemName: String {
        guard let id = selectedItemId else { return "Выберите" }
        
        switch selectedType {
        case .category:
            return categories.first(where: { $0.id == id })?.name ?? "Выберите"
        case .cuisine:
            return cuisines.first(where: { $0.id == id })?.name ?? "Выберите"
        }
    }
    
    private var usageInfo: String? {
        guard let id = selectedItemId else { return nil }
        
        switch selectedType {
        case .category:
            if let category = categories.first(where: { $0.id == id }) {
                if category.count > 0 {
                    return "⚠️ В этой категории \(category.countText). Удаление невозможно."
                } else {
                    return "✅ Категория пуста, можно удалить"
                }
            }
        case .cuisine:
            // Здесь нужно добавить метод для получения количества рецептов по кухне
            // Пока заглушка
            return nil
        }
        return nil
    }
    
    private var confirmMessage: String {
        switch selectedType {
        case .category:
            return "Вы уверены, что хотите удалить категорию «\(selectedItemName)»?"
        case .cuisine:
            return "Вы уверены, что хотите удалить кухню «\(selectedItemName)»?"
        }
    }
    
    private var canDelete: Bool {
        guard let id = selectedItemId else { return false }
        
        switch selectedType {
        case .category:
            if let category = categories.first(where: { $0.id == id }) {
                return category.count == 0
            }
            return false
        case .cuisine:
            // Здесь проверка для кухни
            return true
        }
    }
    
    // MARK: - Functions
    
    private func errorView(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.red)
            .font(.caption)
            .padding()
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
            .cornerRadius(8)
    }
    
    private func loadData() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fetchedCategories = try DatabaseManager.shared.fetchCategories()
                let fetchedCuisines = try DatabaseManager.shared.fetchAllCuisines()
                
                DispatchQueue.main.async {
                    categories = fetchedCategories
                    cuisines = fetchedCuisines
                }
            } catch {
                DispatchQueue.main.async {
                    errorText = error.localizedDescription
                }
            }
        }
    }
    
    private func performDelete() {
        guard let id = selectedItemId else { return }
        
        isDeleting = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                switch selectedType {
                case .category:
                    try DatabaseManager.shared.deleteCategory(id: id)
                case .cuisine:
                    try DatabaseManager.shared.deleteCuisine(id: id)
                }
                
                DispatchQueue.main.async {
                    isDeleting = false
                    loadData() // Перезагружаем данные
                    selectedItemId = nil // Сбрасываем выбор
                }
            } catch {
                DispatchQueue.main.async {
                    errorText = error.localizedDescription
                    isDeleting = false
                    showingConfirmAlert = false
                }
            }
        }
    }
}

#Preview {
    DeleteManagementView()
}
