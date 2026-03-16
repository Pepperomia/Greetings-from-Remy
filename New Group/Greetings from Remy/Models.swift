import Foundation
import SwiftUI

// MARK: - Shopping Item
struct ShoppingItem: Identifiable {
    let id: Int
    let name: String
    let amountText: String?
    let isChecked: Bool
    var uuid = UUID()
}

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
    let cuisineId: Int?
    
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
    
    init(id: Int, title: String, timeMinutes: Int, difficulty: String, calories: Int? = nil, cuisineId: Int? = nil) {
        self.id = id
        self.title = title
        self.timeMinutes = timeMinutes
        self.difficulty = difficulty
        self.calories = calories
        self.cuisineId = cuisineId
    }
}

// MARK: - Recipe Detail
struct RecipeDetail: Identifiable {
    let id: Int
    let title: String
    let categoryName: String
    let cuisineName: String?
    let difficulty: String
    let timeMinutes: Int
    let timeText: String
    let servingsText: String?
    let instructions: String
    let calories: Double?
    let protein: Double?
    let fat: Double?
    let carbs: Double?
    
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
}
