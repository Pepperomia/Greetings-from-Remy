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
        print("📝 Добавление ингредиентов для рецепта \(recipeId)")
        
        for (index, line) in ingredientsLines.enumerated() {
            
            // Проверяем разные возможные разделители
            var parts: [String] = []
            
            if line.contains("—") {
                parts = line.components(separatedBy: "—")
            } else if line.contains("-") {
                parts = line.components(separatedBy: "-")
            } else if line.contains("–") {
                parts = line.components(separatedBy: "–")
            } else {
                parts = [line, ""]
            }
            
            let ingredientName = parts.first?.trimmingCharacters(in: .whitespaces) ?? ""
            let amountText = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
            
            print("  📝 Строка: '\(line)'")
            print("     → название: '\(ingredientName)'")
            print("     → количество: '\(amountText)'")
            
            guard !ingredientName.isEmpty else {
                print("     ⚠️ Пропускаем - пустое название")
                continue
            }
            
            // Находим или создаем ингредиент
            let ingredientId = try findOrCreateIngredient(name: ingredientName)
            print("     ✅ ID ингредиента: \(ingredientId)")
            
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
                    print("     ✅ Сохранено: \(ingredientName) -> '\(amountText)'")
                } else {
                    let error = String(cString: sqlite3_errmsg(db))
                    print("     ❌ Ошибка: \(error)")
                }
            } else {
                let error = String(cString: sqlite3_errmsg(db))
                print("     ❌ Ошибка подготовки: \(error)")
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
        SELECT id, title, time_minutes, difficulty, calories, cuisine_id
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
            let id = row[0] as? Int ?? 0
            let title = row[1] as? String ?? ""
            let timeMinutes = row[2] as? Int ?? 0
            let difficulty = row[3] as? String ?? "medium"
            
            // Получаем Double и конвертируем в Int
            let caloriesValue = row[4] as? Double
            let calories = caloriesValue.map { Int($0) }
            
            // Получаем cuisine_id
            let cuisineId = row[5] as? Int
            
            return RecipeRow(
                id: id,
                title: title,
                timeMinutes: timeMinutes,
                difficulty: difficulty,
                calories: calories,
                cuisineId: cuisineId
            )
        }
    }
    
    
    // MARK: SEARCH

    func searchRecipes(query: String, cuisineId: Int? = nil) throws -> [RecipeRow] {
        var sql = """
        SELECT DISTINCT r.id, r.title, r.time_minutes, r.difficulty, r.calories
        FROM recipes r
        LEFT JOIN recipe_ingredients ri ON ri.recipe_id = r.id
        LEFT JOIN ingredients i ON i.id = ri.ingredient_id
        WHERE r.is_archived = 0
        AND (r.title LIKE ? OR i.name LIKE ?)
        """
        
        var parameters: [Any] = ["%\(query)%", "%\(query)%"]
        
        if let cuisineId = cuisineId {
            sql += " AND r.cuisine_id = ?"
            parameters.append(cuisineId)
        }
        
        sql += " ORDER BY r.title LIMIT 200"
        
        return try runQuery(sql, parameters: parameters) { row in
            let id = row[0] as? Int ?? 0
            let title = row[1] as? String ?? ""
            let timeMinutes = row[2] as? Int ?? 0
            let difficulty = row[3] as? String ?? "medium"
            
            let caloriesValue = row[4] as? Double
            let calories = caloriesValue.map { Int($0) }
            
            return RecipeRow(
                id: id,
                title: title,
                timeMinutes: timeMinutes,
                difficulty: difficulty,
                calories: calories
            )
        }
    }
    
    func searchRecipesByIngredients(_ ingredients: [String], cuisineId: Int? = nil) throws -> [RecipeRow] {
        guard !ingredients.isEmpty else { return [] }
        
        try open()
        
        var sql = """
        SELECT r.id, r.title, r.time_minutes, r.difficulty, r.calories
        FROM recipes r
        WHERE r.is_archived = 0
        """
        
        for _ in ingredients {
            sql += """
            \nAND r.id IN (
                SELECT ri.recipe_id 
                FROM recipe_ingredients ri
                JOIN ingredients i ON i.id = ri.ingredient_id
                WHERE i.name LIKE ?
            )
            """
        }
        
        if cuisineId != nil {
            sql += " AND r.cuisine_id = ?"
        }
        
        sql += "\nORDER BY r.title LIMIT 200"
        
        var parameters: [Any] = ingredients.map { "%\($0)%" }
        
        if let cuisineId = cuisineId {
            parameters.append(cuisineId)
        }
        
        return try runQuery(sql, parameters: parameters) { row in
            let id = row[0] as? Int ?? 0
            let title = row[1] as? String ?? ""
            let timeMinutes = row[2] as? Int ?? 0
            let difficulty = row[3] as? String ?? "medium"
            
            let caloriesValue = row[4] as? Double
            let calories = caloriesValue.map { Int($0) }
            
            return RecipeRow(
                id: id,
                title: title,
                timeMinutes: timeMinutes,
                difficulty: difficulty,
                calories: calories
            )
        }
    }

    func searchIngredientSuggestions(prefix: String) throws -> [String] {
        let sql = """
        SELECT DISTINCT i.name
        FROM ingredients i
        WHERE i.name LIKE ?
        ORDER BY 
            CASE 
                WHEN i.name LIKE ? THEN 1
                WHEN i.name LIKE ? THEN 2
                ELSE 3
            END,
            i.name
        LIMIT 10
        """
        
        let pattern = "%\(prefix)%"
        let exactPattern = "\(prefix)%"
        
        return try runQuery(
            sql,
            parameters: [pattern, exactPattern, pattern]
        ) { row in
            row[0] as? String ?? ""
        }.filter { !$0.isEmpty }
    }

    func getPopularIngredients(limit: Int = 10) throws -> [String] {
        let sql = """
        SELECT i.name, COUNT(*) as usage_count
        FROM ingredients i
        JOIN recipe_ingredients ri ON ri.ingredient_id = i.id
        GROUP BY i.id, i.name
        ORDER BY usage_count DESC, i.name
        LIMIT ?
        """
        
        return try runQuery(sql, parameters: [limit]) { row in
            row[0] as? String ?? ""
        }.filter { !$0.isEmpty }
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
        
        print("🔍 Загрузка ингредиентов для рецепта \(recipeId)")
        
        return try runQuery(sql, parameters: [recipeId]) { row in
            let id = row[0] as? Int ?? 0
            let name = row[1] as? String ?? ""
            let amountText = row[2] as? String ?? ""
            let sortOrder = row[3] as? Int ?? 0
            
            print("   ✅ Ингредиент: \(name) - '\(amountText)'")
            
            return IngredientLine(
                id: id,
                name: name,
                amountText: amountText,
                sortOrder: sortOrder
            )
        }
    }

    // MARK: - Update Recipe

    func updateRecipe(
        recipeId: Int,
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
        
        // Обновляем рецепт
        let sql = """
        UPDATE recipes 
        SET title = ?,
            category_id = ?,
            cuisine_id = ?,
            difficulty = ?,
            time_minutes = ?,
            time_text = ?,
            servings_text = ?,
            instructions = ?,
            calories = ?,
            protein = ?,
            fat = ?,
            carbs = ?
        WHERE id = ? AND is_archived = 0;
        """
        
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "DatabaseManager",
                         code: 5,
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
        
        sqlite3_bind_int(stmt, 13, Int32(recipeId))
        
        if sqlite3_step(stmt) != SQLITE_DONE {
            throw NSError(domain: "DatabaseManager",
                         code: 6,
                         userInfo: [NSLocalizedDescriptionKey: "Ошибка обновления рецепта: \(lastError())"])
        }
        
        print("✅ Рецепт \(recipeId) обновлен: \(title)")
        
        // Удаляем старые ингредиенты
        let deleteSQL = "DELETE FROM recipe_ingredients WHERE recipe_id = ?;"
        var deleteStmt: OpaquePointer?
        defer { sqlite3_finalize(deleteStmt) }
        
        if sqlite3_prepare_v2(db, deleteSQL, -1, &deleteStmt, nil) == SQLITE_OK {
            sqlite3_bind_int(deleteStmt, 1, Int32(recipeId))
            sqlite3_step(deleteStmt)
        }
        
        // Добавляем новые ингредиенты
        try addIngredients(recipeId: recipeId, ingredientsLines: ingredientsLines)
    }

    // MARK: - Fetch Recipe for Editing

    func fetchRecipeForEditing(recipeId: Int) throws -> (detail: RecipeDetail, cuisineId: Int?, ingredients: [IngredientLine]) {
        let detail = try fetchRecipeDetail(recipeId: recipeId)
        let ingredients = try fetchIngredients(recipeId: recipeId)
        
        // Получаем cuisine_id для редактирования
        let sql = "SELECT cuisine_id FROM recipes WHERE id = ?;"
        let cuisineId = try runQuery(sql, parameters: [recipeId]) { row in
            row[0] as? Int
        }.first ?? nil
        
        return (detail, cuisineId, ingredients)
    }
    // MARK: - Favorites Methods
    
    func toggleFavorite(recipeId: Int) throws -> Bool {
        try open()
        
        // Проверяем текущий статус
        let checkSQL = "SELECT is_favorite FROM user_recipe_data WHERE recipe_id = ?;"
        let current: [Bool] = try runQuery(checkSQL, parameters: [recipeId]) { row in
            (row[0] as? Int ?? 0) != 0
        }
        
        let newValue = !(current.first ?? false)
        
        // Вставляем или обновляем
        let sql = """
        INSERT INTO user_recipe_data (recipe_id, is_favorite, cooked_count)
        VALUES (?, ?, 0)
        ON CONFLICT(recipe_id) DO UPDATE SET is_favorite = ?;
        """
        
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "DatabaseManager",
                         code: 7,
                         userInfo: [NSLocalizedDescriptionKey: lastError()])
        }
        
        sqlite3_bind_int(stmt, 1, Int32(recipeId))
        sqlite3_bind_int(stmt, 2, newValue ? 1 : 0)
        sqlite3_bind_int(stmt, 3, newValue ? 1 : 0)
        
        if sqlite3_step(stmt) != SQLITE_DONE {
            throw NSError(domain: "DatabaseManager",
                         code: 8,
                         userInfo: [NSLocalizedDescriptionKey: lastError()])
        }
        
        print("\(newValue ? "✅ Добавлено в избранное" : "❌ Удалено из избранного") рецепт \(recipeId)")
        return newValue
    }

    func getUserRecipeData(recipeId: Int) throws -> (isFavorite: Bool, cookedCount: Int) {
        try open()
        
        let sql = """
        SELECT is_favorite, cooked_count
        FROM user_recipe_data
        WHERE recipe_id = ?
        LIMIT 1;
        """
        
        let rows = try runQuery(sql, parameters: [recipeId]) { row -> (Bool, Int) in
            let isFavorite = (row[0] as? Int ?? 0) != 0
            let cookedCount = row[1] as? Int ?? 0
            return (isFavorite, cookedCount)
        }
        
        if let row = rows.first {
            return row
        } else {
            // Создаем запись по умолчанию
            let insertSQL = """
            INSERT INTO user_recipe_data (recipe_id, is_favorite, cooked_count)
            VALUES (?, 0, 0);
            """
            
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            
            if sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) != SQLITE_OK {
                throw NSError(domain: "DatabaseManager",
                             code: 5,
                             userInfo: [NSLocalizedDescriptionKey: lastError()])
            }
            sqlite3_bind_int(stmt, 1, Int32(recipeId))
            
            if sqlite3_step(stmt) != SQLITE_DONE {
                throw NSError(domain: "DatabaseManager",
                             code: 6,
                             userInfo: [NSLocalizedDescriptionKey: lastError()])
            }
            return (false, 0)
        }
    }

    func fetchFavoriteRecipes() throws -> [RecipeRow] {
        let sql = """
        SELECT r.id, r.title, r.time_minutes, r.difficulty, r.calories
        FROM recipes r
        JOIN user_recipe_data urd ON urd.recipe_id = r.id
        WHERE urd.is_favorite = 1 AND r.is_archived = 0
        ORDER BY r.title;
        """
        
        return try runQuery(sql) { row in
            let id = row[0] as? Int ?? 0
            let title = row[1] as? String ?? ""
            let timeMinutes = row[2] as? Int ?? 0
            let difficulty = row[3] as? String ?? "medium"
            let caloriesValue = row[4] as? Double
            let calories = caloriesValue.map { Int($0) }
            
            return RecipeRow(
                id: id,
                title: title,
                timeMinutes: timeMinutes,
                difficulty: difficulty,
                calories: calories
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
    
    func debugCheckIngredients() throws {
        let sql = """
        SELECT r.title, i.name, ri.amount_text
        FROM recipe_ingredients ri
        JOIN recipes r ON r.id = ri.recipe_id
        JOIN ingredients i ON i.id = ri.ingredient_id
        LIMIT 20
        """
        
        let results = try runQuery(sql, parameters: []) { row in
            let recipe = row[0] as? String ?? ""
            let ingredient = row[1] as? String ?? ""
            let amount = row[2] as? String ?? ""
            return "\(recipe) → \(ingredient) → '\(amount)'"
        }
        
        print("📊 Проверка ингредиентов в базе:")
        if results.isEmpty {
            print("   ❌ Нет данных в таблице recipe_ingredients")
        } else {
            results.forEach { print("   \($0)") }
        }
    }
    
    func simpleDebugCheck() {
        do {
            try open()
            
            let sql = "SELECT COUNT(*) FROM recipe_ingredients"
            var stmt: OpaquePointer?
            
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_ROW {
                    let count = sqlite3_column_int(stmt, 0)
                    print("📊 Всего записей в recipe_ingredients: \(count)")
                }
            }
            sqlite3_finalize(stmt)
            
        } catch {
            print("❌ Ошибка: \(error)")
        }
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


