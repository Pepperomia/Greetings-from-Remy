import Foundation
import SQLite3

// MARK: - Database Manager

final class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: OpaquePointer?
    
    // MARK: - Init
    
    private init() {
        // Индексы создаются при первом открытии
    }
    
    // MARK: - Open Database
    
    private func open() throws {
        if db != nil { return }
        
        let url = DatabaseBootstrap.appDatabaseURL()
        let result = sqlite3_open(url.path, &db)
        
        if result != SQLITE_OK {
            let msg = db.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "Unknown database error"
            sqlite3_close(db)
            db = nil
            throw NSError(domain: "DatabaseManager", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        
        // Оптимизация SQLite
        try execSQL("PRAGMA synchronous = NORMAL;")
        try execSQL("PRAGMA cache_size = 10000;")
        try execSQL("PRAGMA temp_store = MEMORY;")
        
        // Создаём индексы для скорости
        try createIndices()
    }
    
    // MARK: - Indices
    
    private func createIndices() throws {
        // Индексы для рецептов
        try execSQL("CREATE INDEX IF NOT EXISTS idx_recipes_title ON recipes(title);")
        try execSQL("CREATE INDEX IF NOT EXISTS idx_recipes_is_archived ON recipes(is_archived);")
        try execSQL("CREATE INDEX IF NOT EXISTS idx_recipes_category ON recipes(category_id);")
        try execSQL("CREATE INDEX IF NOT EXISTS idx_recipes_cuisine ON recipes(cuisine_id);")
        try execSQL("CREATE INDEX IF NOT EXISTS idx_recipes_time ON recipes(time_minutes);")
        try execSQL("CREATE INDEX IF NOT EXISTS idx_recipes_difficulty ON recipes(difficulty);")
        
        // Индексы для ингредиентов (критично для поиска!)
        try execSQL("CREATE INDEX IF NOT EXISTS idx_ingredients_name ON ingredients(name);")
        try execSQL("CREATE INDEX IF NOT EXISTS idx_recipe_ingredients_recipe ON recipe_ingredients(recipe_id);")
        try execSQL("CREATE INDEX IF NOT EXISTS idx_recipe_ingredients_ingredient ON recipe_ingredients(ingredient_id);")
        
        print("✅ Индексы созданы")
    }
    
    // MARK: - Helpers
    
    private func lastError() -> String {
        guard let db else { return "Database not open" }
        return String(cString: sqlite3_errmsg(db))
    }
    
    private func execSQL(_ sql: String) throws {
        try open()
        var errMsg: UnsafeMutablePointer<Int8>?
        
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            let msg = errMsg.map { String(cString: $0) } ?? lastError()
            sqlite3_free(errMsg)
            throw NSError(domain: "DatabaseManager", code: 200, userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }
    
    private func begin() throws { try execSQL("BEGIN;") }
    private func commit() throws { try execSQL("COMMIT;") }
    private func rollback() { try? execSQL("ROLLBACK;") }
    
    // MARK: - Query Runner
    
    private func runQuery<T>(
        _ sql: String,
        parameters: [Any] = [],
        mapRow: (SQLiteRow) -> T
    ) throws -> [T] {
        try open()
        
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw NSError(domain: "DatabaseManager", code: 1000, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }
        
        // Bind parameters
        for (idx, param) in parameters.enumerated() {
            let bindIdx = Int32(idx + 1)
            
            if let intParam = param as? Int {
                sqlite3_bind_int(stmt, bindIdx, Int32(intParam))
            } else if let stringParam = param as? String {
                sqlite3_bind_text(stmt, bindIdx, (stringParam as NSString).utf8String, -1, nil)
            }
        }
        
        var results: [T] = []
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            let row = SQLiteRow(statement: stmt)
            results.append(mapRow(row))
        }
        
        return results
    }
    
    // MARK: - Recipe Count
    
    func recipeCount() throws -> Int {
        let sql = "SELECT COUNT(*) FROM recipes WHERE is_archived = 0;"
        let resultMap: (SQLiteRow) -> Int = { row in
            return row[0] as? Int ?? 0
        }
        
        let counts = try runQuery(sql, mapRow: resultMap)
        return counts.first ?? 0
    }
    
    // MARK: - Recipe Detail
    
    func fetchRecipeDetail(recipeId: Int) throws -> RecipeDetail {
        let sql = """
            SELECT
                r.id,
                r.title,
                c.name AS category_name,
                cu.name AS cuisine_name,
                r.difficulty,
                r.time_minutes,
                r.servings_text,
                r.instructions
            FROM recipes r
            JOIN categories c ON c.id = r.category_id
            LEFT JOIN cuisines cu ON cu.id = r.cuisine_id
            WHERE r.id = ? AND r.is_archived = 0
            LIMIT 1;
        """
        
        let resultMap: (SQLiteRow) -> RecipeDetail = { row in
            RecipeDetail(
                id: row[0] as? Int ?? 0,
                title: row[1] as? String ?? "",
                categoryName: row[2] as? String ?? "",
                cuisineName: row[3] as? String,
                difficulty: row[4] as? String ?? "medium",
                timeMinutes: row[5] as? Int ?? 0,
                servingsText: row[6] as? String,
                instructions: row[7] as? String ?? ""
            )
        }
        
        let details = try runQuery(sql, parameters: [recipeId], mapRow: resultMap)
        
        guard let detail = details.first else {
            throw NSError(domain: "DatabaseManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Рецепт не найден"])
        }
        
        return detail
    }
    
    // MARK: - Ingredients
    
    func fetchIngredients(recipeId: Int) throws -> [IngredientLine] {
        let sql = """
            SELECT
                ri.id,
                i.name,
                ri.amount_text,
                ri.sort_order
            FROM recipe_ingredients ri
            JOIN ingredients i ON i.id = ri.ingredient_id
            WHERE ri.recipe_id = ?
            ORDER BY ri.sort_order, i.name;
        """
        
        let resultMap: (SQLiteRow) -> IngredientLine = { row in
            IngredientLine(
                id: row[0] as? Int ?? 0,
                name: row[1] as? String ?? "",
                amountText: row[2] as? String ?? "",
                sortOrder: row[3] as? Int ?? 0
            )
        }
        
        return try runQuery(sql, parameters: [recipeId], mapRow: resultMap)
    }
    
    // MARK: - User Data (Favorites & Cooked)
    
    func fetchUserRecipeData(recipeId: Int) throws -> UserRecipeData {
        let sql = """
            SELECT recipe_id, is_favorite, cooked_count
            FROM user_recipe_data
            WHERE recipe_id = ?
            LIMIT 1;
        """
        
        let resultMap: (SQLiteRow) -> UserRecipeData = { row in
            UserRecipeData(
                recipeId: row[0] as? Int ?? 0,
                isFavorite: (row[1] as? Int ?? 0) != 0,
                cookedCount: row[2] as? Int ?? 0
            )
        }
        
        let data = try runQuery(sql, parameters: [recipeId], mapRow: resultMap)
        
        if let existing = data.first {
            return existing
        }
        
        // Create if not exists
        try execSQL("INSERT OR IGNORE INTO user_recipe_data(recipe_id) VALUES (\(recipeId));")
        return UserRecipeData(recipeId: recipeId, isFavorite: false, cookedCount: 0)
    }
    
    func setFavorite(recipeId: Int, isFavorite: Bool) throws {
        let sql = "UPDATE user_recipe_data SET is_favorite = ? WHERE recipe_id = ?;"
        _ = try runQuery(sql, parameters: [isFavorite ? 1 : 0, recipeId]) { _ in }
    }
    
    func incrementCookedCount(recipeId: Int) throws {
        let sql = """
            UPDATE user_recipe_data
            SET cooked_count = cooked_count + 1,
                last_cooked_at = datetime('now')
            WHERE recipe_id = ?;
        """
        _ = try runQuery(sql, parameters: [recipeId]) { _ in }
    }
    
    func fetchFavoriteRecipes() throws -> [RecipeRow] {
        let sql = """
            SELECT r.id, r.title, r.time_minutes, r.difficulty
            FROM recipes r
            JOIN user_recipe_data u ON u.recipe_id = r.id
            WHERE r.is_archived = 0 AND u.is_favorite = 1
            ORDER BY r.title;
        """
        
        let resultMap: (SQLiteRow) -> RecipeRow = { row in
            RecipeRow(
                id: row[0] as? Int ?? 0,
                title: row[1] as? String ?? "",
                timeMinutes: row[2] as? Int ?? 0,
                difficulty: row[3] as? String ?? "medium"
            )
        }
        
        return try runQuery(sql, mapRow: resultMap)
    }
    
    // MARK: - Cuisines
    
    func fetchCuisines() throws -> [CuisineRow] {
        let sql = """
            SELECT cu.id, cu.name
            FROM cuisines cu
            WHERE EXISTS (
                SELECT 1 FROM recipes r
                WHERE r.cuisine_id = cu.id AND r.is_archived = 0
            )
            ORDER BY lower(trim(cu.name));
        """
        
        let resultMap: (SQLiteRow) -> CuisineRow = { row in
            CuisineRow(
                id: row[0] as? Int ?? 0,
                name: row[1] as? String ?? ""
            )
        }
        
        return try runQuery(sql, mapRow: resultMap)
    }
    
    func fetchAllCuisines() throws -> [CuisineRow] {
        let sql = "SELECT id, name FROM cuisines ORDER BY lower(trim(name));"
        
        let resultMap: (SQLiteRow) -> CuisineRow = { row in
            CuisineRow(
                id: row[0] as? Int ?? 0,
                name: row[1] as? String ?? ""
            )
        }
        
        return try runQuery(sql, mapRow: resultMap)
    }
    
    @discardableResult
    func addCuisine(name: String) throws -> Int {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "DatabaseManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Название не может быть пустым"])
        }
        
        // Normalize
        let normalized = trimmed.prefix(1).uppercased() + trimmed.dropFirst().lowercased()
        
        // Check if exists
        let checkSQL = "SELECT id FROM cuisines WHERE lower(trim(name)) = lower(trim(?)) LIMIT 1;"
        let checkResult: (SQLiteRow) -> Int = { row in row[0] as? Int ?? 0 }
        let existing = try runQuery(checkSQL, parameters: [normalized], mapRow: checkResult)
        
        if let id = existing.first, id > 0 {
            return id
        }
        
        // Insert
        let insertSQL = "INSERT INTO cuisines(name) VALUES (?);"
        let insertResult: (SQLiteRow) -> Int = { row in 0 }
        _ = try runQuery(insertSQL, parameters: [normalized], mapRow: insertResult)
        
        // Get last ID
        let lastIdSQL = "SELECT last_insert_rowid();"
        let lastIdResult: (SQLiteRow) -> Int = { row in row[0] as? Int ?? 0 }
        let ids = try runQuery(lastIdSQL, mapRow: lastIdResult)
        
        return ids.first ?? 0
    }
    
    // MARK: - Categories
    
    func fetchCategories() throws -> [CategoryRow] {
        let sql = """
            SELECT c.id, c.name, COUNT(r.id) as cnt
            FROM categories c
            LEFT JOIN recipes r ON r.category_id = c.id AND r.is_archived = 0
            GROUP BY c.id, c.name
            ORDER BY c.sort_order, c.name;
        """
        
        let resultMap: (SQLiteRow) -> CategoryRow = { row in
            CategoryRow(
                id: row[0] as? Int ?? 0,
                name: row[1] as? String ?? "",
                count: row[2] as? Int ?? 0
            )
        }
        
        return try runQuery(sql, mapRow: resultMap)
    }
    
    func fetchRecipes(categoryId: Int) throws -> [RecipeRow] {
        let sql = """
            SELECT id, title, time_minutes, difficulty
            FROM recipes
            WHERE category_id = ? AND is_archived = 0
            ORDER BY title;
        """
        
        let resultMap: (SQLiteRow) -> RecipeRow = { row in
            RecipeRow(
                id: row[0] as? Int ?? 0,
                title: row[1] as? String ?? "",
                timeMinutes: row[2] as? Int ?? 0,
                difficulty: row[3] as? String ?? "medium"
            )
        }
        
        return try runQuery(sql, parameters: [categoryId], mapRow: resultMap)
    }
    
    // MARK: - Search (ОПТИМИЗИРОВАННАЯ ВЕРСИЯ!)
    
    func searchRecipes(
        query: String,
        ingredients: [String]? = nil,
        categoryId: Int? = nil,
        cuisineId: Int? = nil,
        maxMinutes: Int? = nil,
        onlyEasy: Bool = false
    ) throws -> [RecipeRow] {
        
        var sql = """
            SELECT DISTINCT r.id, r.title, r.time_minutes, r.difficulty
            FROM recipes r
            WHERE r.is_archived = 0
        """
        
        var parameters: [Any] = []
        
        // Поиск по названию - это работает всегда, если есть query
        if !query.isEmpty {
            sql += " AND r.title LIKE ?"
            parameters.append("%\(query)%")
        }
        
        // Фильтры
        if let categoryId = categoryId {
            sql += " AND r.category_id = ?"
            parameters.append(categoryId)
        }
        
        if let cuisineId = cuisineId {
            sql += " AND r.cuisine_id = ?"
            parameters.append(cuisineId)
        }
        
        if let maxMinutes = maxMinutes {
            sql += " AND r.time_minutes <= ?"
            parameters.append(maxMinutes)
        }
        
        if onlyEasy {
            sql += " AND r.difficulty = 'easy'"
        }
        
        sql += " ORDER BY r.title LIMIT 100"
        
        let resultMap: (SQLiteRow) -> RecipeRow = { row in
            RecipeRow(
                id: row[0] as? Int ?? 0,
                title: row[1] as? String ?? "",
                timeMinutes: row[2] as? Int ?? 0,
                difficulty: row[3] as? String ?? "medium"
            )
        }
        
        var recipes = try runQuery(sql, parameters: parameters, mapRow: resultMap)
        
        // Фильтр по ингредиентам применяется ТОЛЬКО если они переданы
        if let ingredients = ingredients, !ingredients.isEmpty {
            let lowercasedIngredients = ingredients.map { $0.lowercased() }
            recipes = recipes.filter { recipe in
                do {
                    let recipeIngredients = try fetchIngredients(recipeId: recipe.id)
                    let ingredientNames = recipeIngredients.map { $0.name.lowercased() }
                    return lowercasedIngredients.allSatisfy { ingredient in
                        ingredientNames.contains { $0.contains(ingredient) }
                    }
                } catch {
                    return false
                }
            }
        }
        
        return recipes
    }
    
    // MARK: - Random Recipe

    func randomRecipeId(
        query: String,
        ingredients: [String]? = nil,
        categoryId: Int? = nil,
        cuisineId: Int? = nil,
        maxMinutes: Int? = nil,
        onlyEasy: Bool = false
    ) throws -> Int? {
        
        let recipes = try searchRecipes(
            query: query,
            ingredients: ingredients,
            categoryId: categoryId,
            cuisineId: cuisineId,
            maxMinutes: maxMinutes,
            onlyEasy: onlyEasy
        )
        
        guard !recipes.isEmpty else { return nil }
        
        let randomIndex = Int.random(in: 0..<recipes.count)
        return recipes[randomIndex].id
    }
    
    // MARK: - Ingredient Suggestions
    
    func searchIngredientNames(prefix: String) throws -> [String] {
        let sql = """
            SELECT DISTINCT name 
            FROM ingredients 
            WHERE name LIKE ? 
            ORDER BY name 
            LIMIT 10
        """
        
        let resultMap: (SQLiteRow) -> String = { row in
            row[0] as? String ?? ""
        }
        
        return try runQuery(sql, parameters: ["\(prefix)%"], mapRow: resultMap)
            .filter { !$0.isEmpty }
    }
    
    func getPopularIngredients(limit: Int) throws -> [String] {
        let sql = """
            SELECT i.name, COUNT(*) as count
            FROM ingredients i
            GROUP BY i.name
            ORDER BY count DESC, i.name
            LIMIT ?
        """
        
        let resultMap: (SQLiteRow) -> String = { row in
            row[0] as? String ?? ""
        }
        
        return try runQuery(sql, parameters: [limit], mapRow: resultMap)
            .filter { !$0.isEmpty }
    }
    
    // MARK: - Add / Update / Archive
    
    func addRecipe(
        title: String,
        categoryId: Int,
        cuisineName: String?,
        difficulty: String,
        timeMinutes: Int,
        servingsText: String?,
        instructions: String,
        ingredientsLines: [String]
    ) throws {
        try begin()
        do {
            // Get or create cuisine
            let cuisineId = try getOrCreateCuisineId(name: cuisineName)
            
            // Insert recipe
            let insertSQL = """
                INSERT INTO recipes
                (title, category_id, cuisine_id, difficulty, time_minutes, servings_text, instructions)
                VALUES (?, ?, ?, ?, ?, ?, ?);
            """
            
            let insertResult: (SQLiteRow) -> Int = { _ in 0 }
            _ = try runQuery(
                insertSQL,
                parameters: [
                    title,
                    categoryId,
                    cuisineId as Any,
                    difficulty,
                    timeMinutes,
                    servingsText ?? "",
                    instructions
                ],
                mapRow: insertResult
            )
            
            // Get new recipe ID
            let lastIdSQL = "SELECT last_insert_rowid();"
            let lastIdResult: (SQLiteRow) -> Int = { row in row[0] as? Int ?? 0 }
            let ids = try runQuery(lastIdSQL, mapRow: lastIdResult)
            
            guard let newRecipeId = ids.first, newRecipeId > 0 else {
                throw NSError(domain: "DatabaseManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to get new recipe ID"])
            }
            
            // Add user data record
            try execSQL("INSERT OR IGNORE INTO user_recipe_data(recipe_id) VALUES (\(newRecipeId));")
            
            // Add ingredients
            try saveIngredients(recipeId: newRecipeId, lines: ingredientsLines)
            
            try commit()
        } catch {
            rollback()
            throw error
        }
    }
    
    func updateRecipe(
        recipeId: Int,
        title: String,
        categoryId: Int,
        cuisineName: String?,
        difficulty: String,
        timeMinutes: Int,
        servingsText: String?,
        instructions: String,
        ingredientsLines: [String]
    ) throws {
        try begin()
        do {
            // Get or create cuisine
            let cuisineId = try getOrCreateCuisineId(name: cuisineName)
            
            // Update recipe
            let updateSQL = """
                UPDATE recipes
                SET title = ?,
                    category_id = ?,
                    cuisine_id = ?,
                    difficulty = ?,
                    time_minutes = ?,
                    servings_text = ?,
                    instructions = ?
                WHERE id = ?;
            """
            
            let updateResult: (SQLiteRow) -> Int = { _ in 0 }
            _ = try runQuery(
                updateSQL,
                parameters: [
                    title,
                    categoryId,
                    cuisineId as Any,
                    difficulty,
                    timeMinutes,
                    servingsText ?? "",
                    instructions,
                    recipeId
                ],
                mapRow: updateResult
            )
            
            // Delete old ingredients
            try execSQL("DELETE FROM recipe_ingredients WHERE recipe_id = \(recipeId);")
            
            // Add new ingredients
            try saveIngredients(recipeId: recipeId, lines: ingredientsLines)
            
            try commit()
        } catch {
            rollback()
            throw error
        }
    }
    
    func archiveRecipe(recipeId: Int) throws {
        try execSQL("UPDATE recipes SET is_archived = 1 WHERE id = \(recipeId);")
    }
    
    // MARK: - Comments
    
    func fetchComments(recipeId: Int) throws -> [RecipeComment] {
        try ensureCommentsTable()
        
        let sql = """
            SELECT id, text, created_at
            FROM recipe_comments
            WHERE recipe_id = ?
            ORDER BY id DESC;
        """
        
        let resultMap: (SQLiteRow) -> RecipeComment = { row in
            RecipeComment(
                id: row[0] as? Int ?? 0,
                text: row[1] as? String ?? "",
                createdAtISO: row[2] as? String ?? ""
            )
        }
        
        return try runQuery(sql, parameters: [recipeId], mapRow: resultMap)
    }
    
    func addComment(recipeId: Int, text: String) throws {
        try ensureCommentsTable()
        
        let sql = "INSERT INTO recipe_comments(recipe_id, text) VALUES (?, ?);"
        let resultMap: (SQLiteRow) -> Int = { _ in 0 }
        _ = try runQuery(sql, parameters: [recipeId, text], mapRow: resultMap)
    }
    
    func updateComment(commentId: Int, text: String) throws {
        try ensureCommentsTable()
        
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        
        let sql = "UPDATE recipe_comments SET text = ? WHERE id = ?;"
        let resultMap: (SQLiteRow) -> Int = { _ in 0 }
        _ = try runQuery(sql, parameters: [clean, commentId], mapRow: resultMap)
    }
    
    func deleteComment(commentId: Int) throws {
        try ensureCommentsTable()
        
        let sql = "DELETE FROM recipe_comments WHERE id = ?;"
        let resultMap: (SQLiteRow) -> Int = { _ in 0 }
        _ = try runQuery(sql, parameters: [commentId], mapRow: resultMap)
    }
    
    private func ensureCommentsTable() throws {
        let sql = """
            CREATE TABLE IF NOT EXISTS recipe_comments (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                recipe_id INTEGER NOT NULL,
                text TEXT NOT NULL,
                created_at TEXT NOT NULL DEFAULT (datetime('now'))
            );
        """
        try execSQL(sql)
    }
    
    // MARK: - Initial Data
    
    func ensureInitialData() throws {
        // Categories
        let categories = [
            (10, "Завтраки"), (20, "Салаты"), (30, "Супы"),
            (40, "Горячее"), (50, "Гарниры"), (60, "Выпечка"),
            (70, "Закуски"), (80, "Десерты"), (90, "Напитки")
        ]
        
        for (sort, name) in categories {
            try execSQL("INSERT OR IGNORE INTO categories(name, sort_order) VALUES ('\(name)', \(sort));")
        }
        
        // Cuisines
        let cuisines = ["Русская", "Европейская", "Итальянская", "Греческая", "Азиатская"]
        for name in cuisines {
            try execSQL("INSERT OR IGNORE INTO cuisines(name) VALUES ('\(name)');")
        }
    }
    
    // MARK: - Health Check
    
    func checkDatabaseHealth() throws {
        try open()
        
        let sql = "SELECT name FROM sqlite_master WHERE type='index';"
        let resultMap: (SQLiteRow) -> String = { row in
            row[0] as? String ?? ""
        }
        
        let indices = try runQuery(sql, mapRow: resultMap)
        print("📊 Индексы в базе (\(indices.count)):")
        for name in indices.sorted() {
            print("  - \(name)")
        }
    }
    
    // MARK: - Private Helpers
    
    private func getOrCreateCuisineId(name: String?) throws -> Int? {
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return nil
        }
        
        let normalized = name.prefix(1).uppercased() + name.dropFirst().lowercased()
        
        // Try to find
        let selectSQL = "SELECT id FROM cuisines WHERE lower(trim(name)) = lower(trim(?)) LIMIT 1;"
        let selectResult: (SQLiteRow) -> Int = { row in row[0] as? Int ?? 0 }
        let existing = try runQuery(selectSQL, parameters: [normalized], mapRow: selectResult)
        
        if let id = existing.first, id > 0 {
            return id
        }
        
        // Insert
        let insertSQL = "INSERT INTO cuisines(name) VALUES (?);"
        let insertResult: (SQLiteRow) -> Int = { _ in 0 }
        _ = try runQuery(insertSQL, parameters: [normalized], mapRow: insertResult)
        
        // Get ID
        let lastIdSQL = "SELECT last_insert_rowid();"
        let lastIdResult: (SQLiteRow) -> Int = { row in row[0] as? Int ?? 0 }
        let ids = try runQuery(lastIdSQL, mapRow: lastIdResult)
        
        return ids.first
    }
    
    private func saveIngredients(recipeId: Int, lines: [String]) throws {
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            // Parse ingredient and amount
            let parts = trimmed
                .replacingOccurrences(of: " - ", with: " — ")
                .split(separator: "—", maxSplits: 1)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            
            let ingredientName = parts.first ?? ""
            let amount = parts.count > 1 ? parts[1] : "по вкусу"
            
            if ingredientName.isEmpty { continue }
            
            // Get or create ingredient ID
            let ingredientId = try getOrCreateIngredientId(name: ingredientName)
            
            // Insert relation
            let insertSQL = """
                INSERT INTO recipe_ingredients
                (recipe_id, ingredient_id, amount_text, sort_order)
                VALUES (?, ?, ?, ?);
            """
            
            let insertResult: (SQLiteRow) -> Int = { _ in 0 }
            _ = try runQuery(
                insertSQL,
                parameters: [recipeId, ingredientId, amount, index],
                mapRow: insertResult
            )
        }
    }
    
    private func getOrCreateIngredientId(name: String) throws -> Int {
        let normalized = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try to find
        let selectSQL = "SELECT id FROM ingredients WHERE lower(name) = lower(?) LIMIT 1;"
        let selectResult: (SQLiteRow) -> Int = { row in row[0] as? Int ?? 0 }
        let existing = try runQuery(selectSQL, parameters: [normalized], mapRow: selectResult)
        
        if let id = existing.first, id > 0 {
            return id
        }
        
        // Insert
        let insertSQL = "INSERT INTO ingredients(name) VALUES (?);"
        let insertResult: (SQLiteRow) -> Int = { _ in 0 }
        _ = try runQuery(insertSQL, parameters: [normalized], mapRow: insertResult)
        
        // Get ID
        let lastIdSQL = "SELECT last_insert_rowid();"
        let lastIdResult: (SQLiteRow) -> Int = { row in row[0] as? Int ?? 0 }
        let ids = try runQuery(lastIdSQL, mapRow: lastIdResult)
        
        return ids.first ?? 0
    }
}

// MARK: - SQLite Row Helper

struct SQLiteRow {
    private let statement: OpaquePointer?
    
    init(statement: OpaquePointer?) {
        self.statement = statement
    }
    
    subscript(index: Int) -> Any? {
        let colIdx = Int32(index)
        let type = sqlite3_column_type(statement, colIdx)
        
        switch type {
        case SQLITE_INTEGER:
            return Int(sqlite3_column_int(statement, colIdx))
        case SQLITE_FLOAT:
            return sqlite3_column_double(statement, colIdx)
        case SQLITE_TEXT:
            guard let text = sqlite3_column_text(statement, colIdx) else { return nil }
            return String(cString: text)
        default:
            return nil
        }
    }
}
