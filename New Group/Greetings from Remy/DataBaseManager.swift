import Foundation
import SQLite3

final class DatabaseManager {

    static let shared = DatabaseManager()
    private var db: OpaquePointer?

    private init() {}

    // MARK: OPEN

    private func open() throws {

        if db != nil { return }

        let url = DatabaseBootstrap.appDatabaseURL()

        if sqlite3_open(url.path, &db) != SQLITE_OK {

            let msg = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            db = nil

            throw NSError(
                domain: "DatabaseManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: msg]
            )
        }
    }
    
    // MARK: - Last Error Helper
    
    private func lastError() -> String {
        guard let db else { return "Database not open" }
        return String(cString: sqlite3_errmsg(db))
    }

    // MARK: QUERY RUNNER

    private func runQuery<T>(
        _ sql: String,
        parameters: [Any] = [],
        mapRow: (SQLiteRow) -> T
    ) throws -> [T] {

        try open()

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {

            let msg = String(cString: sqlite3_errmsg(db))

            throw NSError(
                domain: "DatabaseManager",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: msg]
            )
        }

        for (idx, param) in parameters.enumerated() {

            let bind = Int32(idx + 1)

            if let intVal = param as? Int {
                sqlite3_bind_int(stmt, bind, Int32(intVal))
            }
            else if let strVal = param as? String {
                sqlite3_bind_text(stmt, bind, (strVal as NSString).utf8String, -1, nil)
            }
        }

        var results: [T] = []

        while sqlite3_step(stmt) == SQLITE_ROW {

            let row = SQLiteRow(statement: stmt)
            results.append(mapRow(row))
        }

        return results
    }

    // MARK: CATEGORIES

    func fetchCategories() throws -> [CategoryRow] {

        let sql = """
        SELECT c.id, c.name, COUNT(r.id)
        FROM categories c
        LEFT JOIN recipes r ON r.category_id = c.id AND r.is_archived = 0
        GROUP BY c.id, c.name
        ORDER BY c.sort_order, c.name
        """

        return try runQuery(sql) { row in
            CategoryRow(
                id: row[0] as? Int ?? 0,
                name: row[1] as? String ?? "",
                count: row[2] as? Int ?? 0
            )
        }
    }
    
    // MARK: - Add Category
    
    func addCategory(name: String) throws -> Int {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "DatabaseManager",
                         code: 400,
                         userInfo: [NSLocalizedDescriptionKey: "Название категории не может быть пустым"])
        }
        
        try open()
        
        // Проверяем, существует ли уже такая категория
        let checkSQL = "SELECT id FROM categories WHERE name = ? LIMIT 1;"
        let existing: [Int] = try runQuery(checkSQL, parameters: [trimmed]) { row in
            row[0] as? Int ?? 0
        }
        
        if let id = existing.first, id > 0 {
            return id // Возвращаем существующий ID
        }
        
        // Добавляем новую категорию
        let insertSQL = """
        INSERT INTO categories (name, sort_order) 
        VALUES (?, (SELECT IFNULL(MAX(sort_order), 0) + 1 FROM categories));
        """
        
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "DatabaseManager",
                         code: 500,
                         userInfo: [NSLocalizedDescriptionKey: lastError()])
        }
        
        sqlite3_bind_text(stmt, 1, trimmed, -1, nil)
        
        if sqlite3_step(stmt) != SQLITE_DONE {
            throw NSError(domain: "DatabaseManager",
                         code: 501,
                         userInfo: [NSLocalizedDescriptionKey: lastError()])
        }
        
        let newId = Int(sqlite3_last_insert_rowid(db))
        print("✅ Добавлена категория: \(trimmed) (id: \(newId))")
        
        return newId
    }
    
    // MARK: - Add Cuisine
    
    func addCuisine(name: String) throws -> Int {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "DatabaseManager",
                         code: 400,
                         userInfo: [NSLocalizedDescriptionKey: "Название кухни не может быть пустым"])
        }
        
        try open()
        
        // Проверяем, существует ли уже такая кухня
        let checkSQL = "SELECT id FROM cuisines WHERE name = ? LIMIT 1;"
        let existing: [Int] = try runQuery(checkSQL, parameters: [trimmed]) { row in
            row[0] as? Int ?? 0
        }
        
        if let id = existing.first, id > 0 {
            return id // Возвращаем существующий ID
        }
        
        // Добавляем новую кухню
        let insertSQL = "INSERT INTO cuisines (name) VALUES (?);"
        
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "DatabaseManager",
                         code: 500,
                         userInfo: [NSLocalizedDescriptionKey: lastError()])
        }
        
        sqlite3_bind_text(stmt, 1, trimmed, -1, nil)
        
        if sqlite3_step(stmt) != SQLITE_DONE {
            throw NSError(domain: "DatabaseManager",
                         code: 501,
                         userInfo: [NSLocalizedDescriptionKey: lastError()])
        }
        
        let newId = Int(sqlite3_last_insert_rowid(db))
        print("✅ Добавлена кухня: \(trimmed) (id: \(newId))")
        
        return newId
    }
    
    // MARK: - Cuisines

    func fetchCuisines() throws -> [CuisineRow] {
        
        let sql = """
        SELECT id, name
        FROM cuisines
        ORDER BY name;
        """
        
        return try runQuery(sql) { row in
            CuisineRow(
                id: row[0] as? Int ?? 0,
                name: row[1] as? String ?? ""
            )
        }
    }

    // Добавьте этот метод, если его нет:
    func fetchAllCuisines() throws -> [CuisineRow] {
        return try fetchCuisines()
    }
    
    // MARK: - Add Recipe
    
    func addRecipe(
        title: String,
        categoryId: Int,
        cuisineName: String? = nil,
        difficulty: String,
        timeMinutes: Int,
        servingsText: String? = nil,
        instructions: String,
        ingredientsLines: [String],
        calories: Double? = nil,
        protein: Double? = nil,
        fat: Double? = nil,
        carbs: Double? = nil
    ) throws {
        
        try open()
        
        var cuisineId: Int? = nil
        
        // Если указана кухня, находим или создаем её
        if let cuisineName, !cuisineName.trimmingCharacters(in: .whitespaces).isEmpty {
            let trimmed = cuisineName.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Проверяем существующую кухню
            let existing: [Int] = try runQuery(
                "SELECT id FROM cuisines WHERE name = ? LIMIT 1;",
                parameters: [trimmed]
            ) { $0[0] as? Int ?? 0 }
            
            if let id = existing.first {
                cuisineId = id
            } else {
                // Создаем новую кухню
                cuisineId = try addCuisine(name: trimmed)
            }
        }
        
        // Вставляем рецепт
        let sql = """
        INSERT INTO recipes
        (title, category_id, cuisine_id, difficulty,
         time_minutes, time_text, servings_text,
         instructions, calories, protein, fat, carbs, is_archived)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0);
        """
        
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "DatabaseManager",
                         code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Ошибка подготовки запроса: \(lastError())"])
        }
        
        // Биндим параметры
        sqlite3_bind_text(stmt, 1, title, -1, nil)
        sqlite3_bind_int(stmt, 2, Int32(categoryId))
        
        if let cuisineId {
            sqlite3_bind_int(stmt, 3, Int32(cuisineId))
        } else {
            sqlite3_bind_null(stmt, 3)
        }
        
        sqlite3_bind_text(stmt, 4, difficulty, -1, nil)
        sqlite3_bind_int(stmt, 5, Int32(timeMinutes))
        
        let timeText = "\(timeMinutes) мин"
        sqlite3_bind_text(stmt, 6, timeText, -1, nil)
        
        if let servingsText {
            sqlite3_bind_text(stmt, 7, servingsText, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 7)
        }
        
        sqlite3_bind_text(stmt, 8, instructions, -1, nil)
        
        sqlite3_bind_double(stmt, 9, calories ?? 0)
        sqlite3_bind_double(stmt, 10, protein ?? 0)
        sqlite3_bind_double(stmt, 11, fat ?? 0)
        sqlite3_bind_double(stmt, 12, carbs ?? 0)
        
        if sqlite3_step(stmt) != SQLITE_DONE {
            throw NSError(domain: "DatabaseManager",
                         code: 2,
                         userInfo: [NSLocalizedDescriptionKey: "Ошибка вставки рецепта: \(lastError())"])
        }
        
        let recipeId = Int(sqlite3_last_insert_rowid(db))
        print("✅ Добавлен рецепт: \(title) (id: \(recipeId))")
        
        // Добавляем ингредиенты
        try addIngredients(recipeId: recipeId, ingredientsLines: ingredientsLines)
    }
    
    // MARK: - Add Ingredients Helper
    
    private func addIngredients(recipeId: Int, ingredientsLines: [String]) throws {
        
        for (index, line) in ingredientsLines.enumerated() {
            
            // Парсим строку ингредиента (формат: "Название — количество")
            let parts = line
                .components(separatedBy: "—")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            
            let ingredientName = parts.first ?? ""
            let amountText = parts.count > 1 ? parts[1] : ""
            
            guard !ingredientName.isEmpty else { continue }
            
            // Находим или создаем ингредиент
            let ingredientId = try findOrCreateIngredient(name: ingredientName)
            
            // Связываем ингредиент с рецептом
            let linkSQL = """
            INSERT INTO recipe_ingredients
            (recipe_id, ingredient_id, amount_text, sort_order)
            VALUES (?, ?, ?, ?);
            """
            
            var linkStmt: OpaquePointer?
            defer { sqlite3_finalize(linkStmt) }
            
            if sqlite3_prepare_v2(db, linkSQL, -1, &linkStmt, nil) == SQLITE_OK {
                sqlite3_bind_int(linkStmt, 1, Int32(recipeId))
                sqlite3_bind_int(linkStmt, 2, Int32(ingredientId))
                sqlite3_bind_text(linkStmt, 3, amountText, -1, nil)
                sqlite3_bind_int(linkStmt, 4, Int32(index))
                
                if sqlite3_step(linkStmt) == SQLITE_DONE {
                    print("  ✅ Ингредиент: \(ingredientName) -> \(amountText)")
                }
            }
        }
    }
    
    // MARK: - Find or Create Ingredient
    
    private func findOrCreateIngredient(name: String) throws -> Int {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Ищем существующий ингредиент
        let findSQL = "SELECT id FROM ingredients WHERE name = ? LIMIT 1;"
        let existing: [Int] = try runQuery(findSQL, parameters: [trimmed]) { row in
            row[0] as? Int ?? 0
        }
        
        if let id = existing.first, id > 0 {
            return id
        }
        
        // Создаем новый ингредиент
        let insertSQL = "INSERT INTO ingredients (name) VALUES (?);"
        var insertStmt: OpaquePointer?
        defer { sqlite3_finalize(insertStmt) }
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &insertStmt, nil) != SQLITE_OK {
            throw NSError(domain: "DatabaseManager",
                         code: 3,
                         userInfo: [NSLocalizedDescriptionKey: "Ошибка создания ингредиента: \(lastError())"])
        }
        
        sqlite3_bind_text(insertStmt, 1, trimmed, -1, nil)
        
        if sqlite3_step(insertStmt) != SQLITE_DONE {
            throw NSError(domain: "DatabaseManager",
                         code: 4,
                         userInfo: [NSLocalizedDescriptionKey: "Ошибка вставки ингредиента: \(lastError())"])
        }
        
        return Int(sqlite3_last_insert_rowid(db))
    }
    
    // MARK: RECIPES BY CATEGORY

    func fetchRecipes(categoryId: Int, maxMinutes: Int? = nil) throws -> [RecipeRow] {

        var sql = """
        SELECT id, title, time_minutes, difficulty, calories
        FROM recipes
        WHERE category_id = ? AND is_archived = 0
        """

        var params: [Any] = [categoryId]

        if let maxMinutes {
            sql += " AND time_minutes <= ?"
            params.append(maxMinutes)
        }

        sql += " ORDER BY title"

        return try runQuery(sql, parameters: params) { row in

            RecipeRow(
                id: row[0] as? Int ?? 0,
                title: row[1] as? String ?? "",
                timeMinutes: row[2] as? Int ?? 0,
                difficulty: row[3] as? String ?? "medium",
                calories: row[4] as? Int
            )
        }
    }

    // MARK: SEARCH

    func searchRecipes(query: String) throws -> [RecipeRow] {

        let sql = """
        SELECT DISTINCT r.id, r.title, r.time_minutes, r.difficulty, r.calories
        FROM recipes r
        LEFT JOIN recipe_ingredients ri ON ri.recipe_id = r.id
        LEFT JOIN ingredients i ON i.id = ri.ingredient_id
        WHERE r.is_archived = 0
        AND (r.title LIKE ? OR i.name LIKE ?)
        ORDER BY r.title
        LIMIT 200
        """

        return try runQuery(
            sql,
            parameters: ["%\(query)%", "%\(query)%"]
        ) { row in

            RecipeRow(
                id: row[0] as? Int ?? 0,
                title: row[1] as? String ?? "",
                timeMinutes: row[2] as? Int ?? 0,
                difficulty: row[3] as? String ?? "medium",
                calories: row[4] as? Int ?? 0
            )
        }
    }

    // MARK: RECIPE DETAIL

    func fetchRecipeDetail(recipeId: Int) throws -> RecipeDetail {

        let sql = """
        SELECT r.id, r.title, c.name, cu.name, r.difficulty,
               r.time_minutes, r.servings_text, r.instructions,
               r.calories, r.protein, r.fat, r.carbs
        FROM recipes r
        JOIN categories c ON c.id = r.category_id
        LEFT JOIN cuisines cu ON cu.id = r.cuisine_id
        WHERE r.id = ? AND r.is_archived = 0
        LIMIT 1
        """

        let rows = try runQuery(sql, parameters: [recipeId]) { row in

            let minutes = row[5] as? Int ?? 0

            return RecipeDetail(
                id: row[0] as? Int ?? 0,
                title: row[1] as? String ?? "",
                categoryName: row[2] as? String ?? "",
                cuisineName: row[3] as? String,
                difficulty: row[4] as? String ?? "medium",
                timeMinutes: minutes,
                timeText: "\(minutes) мин",
                servingsText: row[6] as? String,
                instructions: row[7] as? String ?? "",
                calories: row[8] as? Double,
                protein: row[9] as? Double,
                fat: row[10] as? Double,
                carbs: row[11] as? Double
            )
        }

        guard let recipe = rows.first else {

            throw NSError(
                domain: "DatabaseManager",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey:"Recipe not found"]
            )
        }

        return recipe
    }

    // MARK: INGREDIENTS

    func fetchIngredients(recipeId: Int) throws -> [IngredientLine] {

        let sql = """
        SELECT ri.id, i.name, ri.amount_text, ri.sort_order
        FROM recipe_ingredients ri
        JOIN ingredients i ON i.id = ri.ingredient_id
        WHERE ri.recipe_id = ?
        ORDER BY ri.sort_order
        """

        return try runQuery(sql, parameters:[recipeId]) { row in

            IngredientLine(
                id: row[0] as? Int ?? 0,
                name: row[1] as? String ?? "",
                amountText: row[2] as? String ?? "",
                sortOrder: row[3] as? Int ?? 0
            )
        }
    }
    
    // MARK: - Debug Methods
    
    func debugLastAddedItems() throws {
        print("\n=== ПОСЛЕДНИЕ ДОБАВЛЕННЫЕ ЭЛЕМЕНТЫ ===")
        
        // Последние 3 категории
        let categoriesSQL = """
        SELECT id, name, sort_order 
        FROM categories 
        ORDER BY id DESC 
        LIMIT 3;
        """
        let categories = try runQuery(categoriesSQL) { row -> String in
            let id = row[0] as? Int ?? 0
            let name = row[1] as? String ?? ""
            let sort = row[2] as? Int ?? 0
            return "  📁 \(id): \(name) (sort: \(sort))"
        }
        print("Последние категории:")
        categories.forEach { print($0) }
        
        // Последние 3 кухни
        let cuisinesSQL = """
        SELECT id, name 
        FROM cuisines 
        ORDER BY id DESC 
        LIMIT 3;
        """
        let cuisines = try runQuery(cuisinesSQL) { row -> String in
            let id = row[0] as? Int ?? 0
            let name = row[1] as? String ?? ""
            return "  🍳 \(id): \(name)"
        }
        print("Последние кухни:")
        cuisines.forEach { print($0) }
        
        // Последние 3 рецепта с ингредиентами
        let recipesSQL = """
        SELECT r.id, r.title, COUNT(ri.id) as ing_count
        FROM recipes r
        LEFT JOIN recipe_ingredients ri ON ri.recipe_id = r.id
        WHERE r.is_archived = 0
        GROUP BY r.id
        ORDER BY r.id DESC
        LIMIT 3;
        """
        let recipes = try runQuery(recipesSQL) { row -> String in
            let id = row[0] as? Int ?? 0
            let title = row[1] as? String ?? ""
            let ingCount = row[2] as? Int ?? 0
            return "  📝 \(id): \(title) (ингредиентов: \(ingCount))"
        }
        print("Последние рецепты:")
        recipes.forEach { print($0) }
        
        print("===============================\n")
    }
    
    // MARK: - Delete Methods
    
    func deleteRecipe(id: Int) throws {
        try open()
        
        let sql = "UPDATE recipes SET is_archived = 1 WHERE id = ?;"
        
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "DatabaseManager",
                         code: 501,
                         userInfo: [NSLocalizedDescriptionKey: lastError()])
        }
        
        sqlite3_bind_int(stmt, 1, Int32(id))
        
        if sqlite3_step(stmt) != SQLITE_DONE {
            throw NSError(domain: "DatabaseManager",
                         code: 502,
                         userInfo: [NSLocalizedDescriptionKey: lastError()])
        }
        
        print("✅ Рецепт \(id) архивирован")
    }

    func deleteCategory(id: Int) throws {
        try open()
        
        // Проверяем, есть ли рецепты в этой категории
        let checkSQL = "SELECT COUNT(*) FROM recipes WHERE category_id = ? AND is_archived = 0;"
        let count = try runQuery(checkSQL, parameters: [id]) { row in
            row[0] as? Int ?? 0
        }.first ?? 0
        
        if count > 0 {
            throw NSError(domain: "DatabaseManager",
                         code: 503,
                         userInfo: [NSLocalizedDescriptionKey: "Нельзя удалить категорию, в которой есть рецепты"])
        }
        
        // Удаляем категорию
        let sql = "DELETE FROM categories WHERE id = ?;"
        
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "DatabaseManager",
                         code: 504,
                         userInfo: [NSLocalizedDescriptionKey: lastError()])
        }
        
        sqlite3_bind_int(stmt, 1, Int32(id))
        
        if sqlite3_step(stmt) != SQLITE_DONE {
            throw NSError(domain: "DatabaseManager",
                         code: 505,
                         userInfo: [NSLocalizedDescriptionKey: lastError()])
        }
        
        print("✅ Категория \(id) удалена")
    }

    func deleteCuisine(id: Int) throws {
        try open()
        
        // Проверяем, есть ли рецепты с этой кухней
        let checkSQL = "SELECT COUNT(*) FROM recipes WHERE cuisine_id = ? AND is_archived = 0;"
        let count = try runQuery(checkSQL, parameters: [id]) { row in
            row[0] as? Int ?? 0
        }.first ?? 0
        
        if count > 0 {
            throw NSError(domain: "DatabaseManager",
                         code: 506,
                         userInfo: [NSLocalizedDescriptionKey: "Нельзя удалить кухню, которая используется в рецептах"])
        }
        
        // Удаляем кухню
        let sql = "DELETE FROM cuisines WHERE id = ?;"
        
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "DatabaseManager",
                         code: 507,
                         userInfo: [NSLocalizedDescriptionKey: lastError()])
        }
        
        sqlite3_bind_int(stmt, 1, Int32(id))
        
        if sqlite3_step(stmt) != SQLITE_DONE {
            throw NSError(domain: "DatabaseManager",
                         code: 508,
                         userInfo: [NSLocalizedDescriptionKey: lastError()])
        }
        
        print("✅ Кухня \(id) удалена")
    }
}

// MARK: - SQLiteRow

struct SQLiteRow {
    private let stmt: OpaquePointer?

    init(statement: OpaquePointer?) {
        self.stmt = statement
    }

    subscript(index: Int) -> Any? {
        let type = sqlite3_column_type(stmt, Int32(index))

        switch type {
        case SQLITE_INTEGER:
            return Int(sqlite3_column_int(stmt, Int32(index)))
        case SQLITE_FLOAT:
            return sqlite3_column_double(stmt, Int32(index))
        case SQLITE_TEXT:
            if let txt = sqlite3_column_text(stmt, Int32(index)) {
                return String(cString: txt)
            }
            return nil
        default:
            return nil
        }
    }
}
