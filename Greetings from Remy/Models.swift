import Foundation

struct CuisineRow: Identifiable, Hashable {
    let id: Int
    let name: String
}

struct CategoryRow: Identifiable {
    let id: Int
    let name: String
    let count: Int
}

struct RecipeRow: Identifiable {
    let id: Int
    let title: String
    let timeMinutes: Int
    let difficulty: String
}
