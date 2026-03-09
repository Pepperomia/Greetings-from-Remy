import Foundation
import SwiftUI

// MARK: - Cuisine

struct CuisineRow: Identifiable, Hashable {
    let id: Int
    let name: String
    
    var displayName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Category

struct CategoryRow: Identifiable, Hashable {
    let id: Int
    let name: String
    let count: Int
    
    var displayName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
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

// MARK: - Recipe Row

struct RecipeRow: Identifiable {
    let id: Int
    let title: String
    let timeMinutes: Int
    let difficulty: String
    let calories: Int?
    let cuisineId: Int?  // Добавляем поле

    var timeText: String {
        "\(timeMinutes) мин"
    }
    
    var difficultyText: String {
        switch difficulty {
        case "easy": return "легко"
        case "hard": return "сложно"
        default: return "средне"
        }
    }
    
    // Инициализатор для fetchRecipes с cuisineId
    init(id: Int, title: String, timeMinutes: Int, difficulty: String, calories: Int? = nil, cuisineId: Int? = nil) {
        self.id = id
        self.title = title
        self.timeMinutes = timeMinutes
        self.difficulty = difficulty
        self.calories = calories
        self.cuisineId = cuisineId
    }
    
    // Инициализатор для других методов (без cuisineId)
    init(id: Int, title: String, timeText: String, difficultyText: String, calories: Int? = nil) {
        self.id = id
        self.title = title
        self.timeMinutes = 0
        self.difficulty = {
            switch difficultyText {
            case "легко": return "easy"
            case "сложно": return "hard"
            default: return "medium"
            }
        }()
        self.calories = calories
        self.cuisineId = nil
    }
}

// MARK: - Recipe Detail

struct RecipeDetail: Identifiable {
    let id: Int
    let title: String
    
    let categoryName: String
    let cuisineName: String?
    
    let difficulty: String        // "easy" / "medium" / "hard"
    let timeMinutes: Int
    let timeText: String
    
    let servingsText: String?
    let instructions: String
    
    let calories: Double?
    let protein: Double?
    let fat: Double?
    let carbs: Double?
    
    // MARK: - Derived
    
    var difficultyText: String {
        switch difficulty {
        case "easy": return "легко"
        case "medium": return "средне"
        case "hard": return "сложно"
        default: return difficulty
        }
    }
    
    var metaLine: String {
        var parts: [String] = []
        
        if !timeText.isEmpty {
            parts.append(timeText)
        }
        
        parts.append(difficultyText)
        
        if let servings = servingsText,
           !servings.isEmpty {
            parts.append("Порции: \(servings)")
        }
        
        return parts.joined(separator: " • ")
    }
}

// MARK: - Ingredient Line

struct IngredientLine: Identifiable {
    let id: Int
    let name: String
    let amountText: String
    let sortOrder: Int
    
    // Добавим вычисляемое свойство для отладки
    var debugDescription: String {
        return "\(name) - \(amountText)"
    }
}

// MARK: - User Recipe Data

struct UserRecipeData {
    let recipeId: Int
    let isFavorite: Bool
    let cookedCount: Int
    let notes: String?
}

// MARK: - Preview Helpers

extension CategoryRow {
    static var preview: CategoryRow {
        CategoryRow(id: 1, name: "Салаты", count: 5)
    }
    
    static var previews: [CategoryRow] {
        [
            CategoryRow(id: 1, name: "Салаты", count: 5),
            CategoryRow(id: 2, name: "Супы", count: 3),
            CategoryRow(id: 3, name: "Десерты", count: 0)
        ]
    }
}

extension CuisineRow {
    static var preview: CuisineRow {
        CuisineRow(id: 1, name: "Итальянская")
    }
    
    static var previews: [CuisineRow] {
        [
            CuisineRow(id: 1, name: "Итальянская"),
            CuisineRow(id: 2, name: "Французская"),
            CuisineRow(id: 3, name: "Японская")
        ]
    }
}

extension RecipeRow {
    static var preview: RecipeRow {
        RecipeRow(id: 1, title: "Цезарь с курицей", timeMinutes: 25, difficulty: "easy", calories: 350)
    }
    
    // MARK: - Recipe Row
    
    struct RecipeRow: Identifiable {
        let id: Int
        let title: String
        let timeMinutes: Int
        let difficulty: String
        let calories: Int?
        let cuisineId: Int?  // Добавляем поле для кухни
        
        var timeText: String {
            "\(timeMinutes) мин"
        }
        
        var difficultyText: String {
            switch difficulty {
            case "easy": return "легко"
            case "hard": return "сложно"
            default: return "средне"
            }
        }
        
        var caloriesText: String? {
            guard let calories = calories, calories > 0 else { return nil }
            return "\(calories) ккал"
        }
        
        // Инициализатор для поиска
        init(id: Int, title: String, timeMinutes: Int, difficulty: String, calories: Int? = nil, cuisineId: Int? = nil) {
            self.id = id
            self.title = title
            self.timeMinutes = timeMinutes
            self.difficulty = difficulty
            self.calories = calories
            self.cuisineId = cuisineId
        }
        
        // Инициализатор для других методов
        init(id: Int, title: String, timeText: String, difficultyText: String, calories: Int? = nil, cuisineId: Int? = nil) {
            self.id = id
            self.title = title
            self.timeMinutes = 0
            self.difficulty = {
                switch difficultyText {
                case "легко": return "easy"
                case "сложно": return "hard"
                default: return "medium"
                }
            }()
            self.calories = calories
            self.cuisineId = cuisineId
        }
    }
}
