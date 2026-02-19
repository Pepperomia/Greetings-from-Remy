import Foundation

// MARK: - Cuisine

struct CuisineRow: Identifiable, Hashable {
    let id: Int
    let name: String
    
    var displayName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
    }
}

// MARK: - Category

struct CategoryRow: Identifiable, Hashable {
    let id: Int
    let name: String
    let count: Int
    
    var displayName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
    }
    
    var countText: String {
        "\(count) \(pluralize(count))"
    }
    
    private func pluralize(_ number: Int) -> String {
        let mod10 = number % 10
        let mod100 = number % 100
        
        if mod10 == 1 && mod100 != 11 {
            return "рецепт"
        } else if mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20) {
            return "рецепта"
        } else {
            return "рецептов"
        }
    }
}

// MARK: - Recipe Row (для списков)

struct RecipeRow: Identifiable, Hashable {
    let id: Int
    let title: String
    let timeMinutes: Int
    let difficulty: String
    
    var difficultyDisplay: String {
        switch difficulty {
        case "easy": return "легко"
        case "hard": return "сложно"
        default: return "средне"
        }
    }
    
    var timeDisplay: String {
        "\(timeMinutes) мин"
    }
    
    var subtitle: String {
        "\(timeDisplay) • \(difficultyDisplay)"
    }
}

// MARK: - Recipe Detail (полная информация)

struct RecipeDetail: Identifiable {
    let id: Int
    let title: String
    let categoryName: String
    let cuisineName: String?
    let difficulty: String
    let timeMinutes: Int
    let servingsText: String?
    let instructions: String
    
    init(
        id: Int,
        title: String,
        categoryName: String,
        cuisineName: String?,
        difficulty: String,
        timeMinutes: Int,
        servingsText: String?,
        instructions: String
    ) {
        self.id = id
        self.title = title
        self.categoryName = categoryName
        self.cuisineName = cuisineName
        self.difficulty = difficulty
        self.timeMinutes = timeMinutes
        self.servingsText = servingsText
        self.instructions = instructions
    }
    
    var difficultyDisplay: String {
        switch difficulty {
        case "easy": return "легко"
        case "hard": return "сложно"
        default: return "средне"
        }
    }
    
    var timeDisplay: String {
        "\(timeMinutes) мин"
    }
    
    var servingsDisplay: String {
        servingsText ?? "—"
    }
    
    var cuisineDisplay: String {
        cuisineName ?? "Не указана"
    }
    
    var metaLine: String {
        var parts: [String] = []
        
        if timeMinutes > 0 {
            parts.append(timeDisplay)
        }
        
        parts.append(difficultyDisplay)
        
        if let servings = servingsText, !servings.isEmpty {
            parts.append("Порции: \(servings)")
        }
        
        if let cuisine = cuisineName, !cuisine.isEmpty {
            parts.append("Кухня: \(cuisine)")
        }
        
        return parts.joined(separator: " • ")
    }
}

// MARK: - Ingredient Line

struct IngredientLine: Identifiable, Hashable {
    let id: Int
    let name: String
    let amountText: String
    let sortOrder: Int
    
    init(
        id: Int,
        name: String,
        amountText: String,
        sortOrder: Int
    ) {
        self.id = id
        self.name = name
        self.amountText = amountText
        self.sortOrder = sortOrder
    }
    
    var displayText: String {
        "\(name) — \(amountText)"
    }
}

// MARK: - User Data

struct UserRecipeData: Identifiable {
    let recipeId: Int
    let isFavorite: Bool
    let cookedCount: Int
    
    var id: Int { recipeId }
    
    init(
        recipeId: Int,
        isFavorite: Bool,
        cookedCount: Int
    ) {
        self.recipeId = recipeId
        self.isFavorite = isFavorite
        self.cookedCount = cookedCount
    }
}

// MARK: - Comment

struct RecipeComment: Identifiable, Hashable {
    let id: Int
    let text: String
    let createdAtISO: String
    
    init(
        id: Int,
        text: String,
        createdAtISO: String
    ) {
        self.id = id
        self.text = text
        self.createdAtISO = createdAtISO
    }
    
    var createdAtText: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: createdAtISO) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            displayFormatter.locale = Locale(identifier: "ru_RU")
            return displayFormatter.string(from: date)
        }
        
        // Fallback для простого формата
        let s = createdAtISO.replacingOccurrences(of: "T", with: " ")
        return String(s.prefix(16))
    }
}

// MARK: - Preview Data

extension RecipeRow {
    static let preview = RecipeRow(
        id: 1,
        title: "Борщ с пампушками",
        timeMinutes: 60,
        difficulty: "medium"
    )
}

extension CategoryRow {
    static let preview = CategoryRow(
        id: 1,
        name: "Супы",
        count: 42
    )
}

extension CuisineRow {
    static let preview = CuisineRow(
        id: 1,
        name: "Русская"
    )
}

extension RecipeDetail {
    static let preview = RecipeDetail(
        id: 1,
        title: "Борщ с пампушками",
        categoryName: "Супы",
        cuisineName: "Русская",
        difficulty: "medium",
        timeMinutes: 60,
        servingsText: "4-6",
        instructions: "1. Сварить бульон\n2. Добавить овощи\n3. Подавать со сметаной"
    )
}

extension IngredientLine {
    static let preview = IngredientLine(
        id: 1,
        name: "Свекла",
        amountText: "2 шт",
        sortOrder: 1
    )
}

extension RecipeComment {
    static let preview = RecipeComment(
        id: 1,
        text: "Очень вкусно! Готовила уже три раза",
        createdAtISO: "2024-02-19T15:30:00Z"
    )
}
