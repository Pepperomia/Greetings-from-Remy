import Foundation

struct RecipeDetail {
    let id: Int
    let title: String
    let categoryName: String
    let cuisineName: String?
    let difficulty: String
    let timeMinutes: Int
    let servingsText: String?
    let instructions: String
}

struct IngredientLine: Identifiable {
    let id: Int            // id строки recipe_ingredients
    let name: String
    let amountText: String
    let sortOrder: Int
}
