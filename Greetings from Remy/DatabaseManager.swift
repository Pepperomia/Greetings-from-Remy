import Foundation
import SQLite3

final class DatabaseManager {

    static let shared = DatabaseManager()
    private var db: OpaquePointer?

    private init() {}

    // MARK: - Open

    private func open() throws {
        if db != nil { return }

        let url = DatabaseBootstrap.appDatabaseURL()

        if sqlite3_open(url.path, &db) != SQLITE_OK {
            throw NSError(domain: "DB",
                          code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Не удалось открыть базу"])
        }
    }

    private func lastError() -> String {
        guard let db else { return "DB not open" }
        return String(cString: sqlite3_errmsg(db))
    }

    // MARK: - SQLiteRow

    struct SQLiteRow {
        let statement: OpaquePointer?

        subscript(index: Int) -> Any? {
            guard let statement else { return nil }

            let type = sqlite3_column_type(statement, Int32(index))

            switch type {
            case SQLITE_INTEGER:
                return Int(sqlite3_column_int(statement, Int32(index)))
            case SQLITE_FLOAT:
                return sqlite3_column_double(statement, Int32(index))
            case SQLITE_TEXT:
                if let text = sqlite3_column_text(statement, Int32(index)) {
                    return String(cString: text)
                }
                return nil
            default:
                return nil
            }
        }
    }

    // MARK: - Generic Query

    private func queryRows<T>(
        _ sql: String,
        parameters: [Any] = [],
        map: (SQLiteRow) -> T
    ) throws -> [T] {

        try open()

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "DB",
                          code: 2,
                          userInfo: [NSLocalizedDescriptionKey: lastError()])
        }

        for (index, param) in parameters.enumerated() {
            let idx = Int32(index + 1)

            if let intVal = param as? Int {
                sqlite3_bind_int(stmt, idx, Int32(intVal))
            } else if let strVal = param as? String {
                sqlite3_bind_text(stmt, idx, strVal, -1, nil)
            }
        }

        var result: [T] = []

        while sqlite3_step(stmt) == SQLITE_ROW {
            result.append(map(SQLiteRow(statement: stmt)))
        }

        return result
    }

    // MARK: - Difficulty Helper

    private func difficultyTextFromCode(_ code: String) -> String {
        switch code {
        case "easy": return "легко"
        case "hard": return "сложно"
        default: return "средне"
        }
    }

    // MARK: - Categories

    func fetchCategories() throws -> [CategoryRow] {

        let sql = """
        SELECT c.id, c.name, COUNT(r.id)
        FROM categories c
        LEFT JOIN recipes r
            ON r.category_id = c.id
            AND r.is_archived = 0
        GROUP BY c.id
        ORDER BY c.sort_order;
        """

        return try queryRows(sql) { row in
            CategoryRow(
                id: row[0] as? Int ?? 0,
                name: row[1] as? String ?? "",
                count: row[2] as? Int ?? 0
            )
        }
    }

    // MARK: - Cuisines

    func fetchCuisines() throws -> [CuisineRow] {

        let sql = """
        SELECT id, name
        FROM cuisines
        ORDER BY name;
        """

        return try queryRows(sql) { row in
            CuisineRow(
                id: row[0] as? Int ?? 0,
                name: row[1] as? String ?? ""
            )
        }
    }

    // MARK: - Search Recipes

    func searchRecipes(
        searchText: String,
        ingredients: [String]?,
        categoryId: Int?,
        cuisineId: Int?,
        maxMinutes: Int?,
        onlyEasy: Bool
    ) throws -> [RecipeRow] {

        var sql = """
        SELECT r.id, r.title, r.time_text, r.difficulty
        FROM recipes r
        """

        var conditions: [String] = ["r.is_archived = 0"]
        var parameters: [Any] = []

        if let categoryId {
            conditions.append("r.category_id = ?")
            parameters.append(categoryId)
        }

        if let cuisineId {
            conditions.append("r.cuisine_id = ?")
            parameters.append(cuisineId)
        }

        if let maxMinutes {
            conditions.append("r.time_minutes <= ?")
            parameters.append(maxMinutes)
        }

        if onlyEasy {
            conditions.append("r.difficulty = 'easy'")
        }

        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            conditions.append("LOWER(r.title) LIKE ?")
            parameters.append("%\(searchText.lowercased())%")
        }

        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }

        sql += " ORDER BY r.title;"

        return try queryRows(sql, parameters: parameters) { row in
            RecipeRow(
                id: row[0] as? Int ?? 0,
                title: row[1] as? String ?? "",
                timeText: row[2] as? String ?? "",
                difficultyText: difficultyTextFromCode(row[3] as? String ?? "medium")
            )
        }
    }

    // MARK: - Random Recipe

    func randomRecipeId(
        searchText: String,
        ingredients: [String]?,
        categoryId: Int?,
        cuisineId: Int?,
        maxMinutes: Int?,
        onlyEasy: Bool
    ) throws -> Int? {

        var sql = """
        SELECT r.id
        FROM recipes r
        """

        var conditions: [String] = ["r.is_archived = 0"]
        var parameters: [Any] = []

        if let categoryId {
            conditions.append("r.category_id = ?")
            parameters.append(categoryId)
        }

        if let cuisineId {
            conditions.append("r.cuisine_id = ?")
            parameters.append(cuisineId)
        }

        if let maxMinutes {
            conditions.append("r.time_minutes <= ?")
            parameters.append(maxMinutes)
        }

        if onlyEasy {
            conditions.append("r.difficulty = 'easy'")
        }

        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            conditions.append("LOWER(r.title) LIKE ?")
            parameters.append("%\(searchText.lowercased())%")
        }

        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }

        sql += " ORDER BY RANDOM() LIMIT 1;"

        let result: [Int] = try queryRows(sql, parameters: parameters) { row in
            row[0] as? Int ?? 0
        }

        return result.first
    }

    // MARK: - Recipe Detail

    func fetchRecipeDetail(recipeId: Int) throws -> RecipeDetail {

        let sql = """
        SELECT
            r.id,
            r.title,
            c.name,
            cu.name,
            r.difficulty,
            r.time_minutes,
            r.time_text,
            r.servings_text,
            r.instructions,
            r.calories,
            r.protein,
            r.fat,
            r.carbs
        FROM recipes r
        JOIN categories c ON c.id = r.category_id
        LEFT JOIN cuisines cu ON cu.id = r.cuisine_id
        WHERE r.id = ?
          AND r.is_archived = 0
        LIMIT 1;
        """

        let rows = try queryRows(sql, parameters: [recipeId]) { row in

            RecipeDetail(
                id: row[0] as? Int ?? 0,
                title: row[1] as? String ?? "",
                categoryName: row[2] as? String ?? "",
                cuisineName: row[3] as? String,
                difficulty: row[4] as? String ?? "medium",
                timeMinutes: row[5] as? Int ?? 0,
                timeText: row[6] as? String ?? "",
                servingsText: row[7] as? String,
                instructions: row[8] as? String ?? "",
                calories: row[9] as? Double,
                protein: row[10] as? Double,
                fat: row[11] as? Double,
                carbs: row[12] as? Double
            )
        }

        guard let detail = rows.first else {
            throw NSError(domain: "DB",
                          code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "Рецепт не найден"])
        }

        return detail
    }
    // MARK: - Ingredients

    func fetchIngredients(recipeId: Int) throws -> [IngredientLine] {

        let sql = """
        SELECT ri.id,
               i.name,
               ri.amount_text,
               ri.sort_order
        FROM recipe_ingredients ri
        JOIN ingredients i ON i.id = ri.ingredient_id
        WHERE ri.recipe_id = ?
        ORDER BY ri.sort_order;
        """

        return try queryRows(sql, parameters: [recipeId]) { row in
            IngredientLine(
                id: row[0] as? Int ?? 0,
                name: row[1] as? String ?? "",
                amountText: row[2] as? String ?? "",
                sortOrder: row[3] as? Int ?? 0
            )
        }
    }
    // MARK: - Fetch Recipes by Category

    func fetchRecipes(categoryId: Int) throws -> [RecipeRow] {

        let sql = """
        SELECT r.id,
               r.title,
               r.time_text,
               r.difficulty
        FROM recipes r
        WHERE r.category_id = ?
          AND r.is_archived = 0
        ORDER BY r.title;
        """

        return try queryRows(sql, parameters: [categoryId]) { row in
            RecipeRow(
                id: row[0] as? Int ?? 0,
                title: row[1] as? String ?? "",
                timeText: row[2] as? String ?? "",
                difficultyText: difficultyTextFromCode(row[3] as? String ?? "medium")
            )
        }
    }
    // MARK: - Add Cuisine

    func addCuisine(name: String) throws -> Int {

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "DB",
                          code: 400,
                          userInfo: [NSLocalizedDescriptionKey: "Название не может быть пустым"])
        }

        try open()

        let checkSQL = """
        SELECT id
        FROM cuisines
        WHERE lower(trim(name)) = lower(trim(?))
        LIMIT 1;
        """

        let existing: [Int] = try queryRows(checkSQL, parameters: [trimmed]) {
            $0[0] as? Int ?? 0
        }

        if let id = existing.first, id > 0 {
            return id
        }

        let insertSQL = "INSERT INTO cuisines(name) VALUES (?);"

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        if sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "DB",
                          code: 500,
                          userInfo: [NSLocalizedDescriptionKey: lastError()])
        }

        sqlite3_bind_text(stmt, 1, trimmed, -1, nil)

        if sqlite3_step(stmt) != SQLITE_DONE {
            throw NSError(domain: "DB",
                          code: 501,
                          userInfo: [NSLocalizedDescriptionKey: lastError()])
        }

        return Int(sqlite3_last_insert_rowid(db))
    }
    
    // MARK: - Update Recipe

    func updateRecipe(
        recipeId: Int,
        title: String,
        categoryId: Int,
        difficulty: String,
        timeMinutes: Int,
        servingsText: String?,
        instructions: String
    ) throws {

        try open()

        let sql = """
        UPDATE recipes
        SET title = ?,
            category_id = ?,
            difficulty = ?,
            time_minutes = ?,
            time_text = ?,
            servings_text = ?,
            instructions = ?
        WHERE id = ?;
        """

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "DB", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: lastError()])
        }

        sqlite3_bind_text(stmt, 1, title, -1, nil)
        sqlite3_bind_int(stmt, 2, Int32(categoryId))
        sqlite3_bind_text(stmt, 3, difficulty, -1, nil)
        sqlite3_bind_int(stmt, 4, Int32(timeMinutes))
        sqlite3_bind_text(stmt, 5, "\(timeMinutes) мин", -1, nil)

        if let servingsText {
            sqlite3_bind_text(stmt, 6, servingsText, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 6)
        }

        sqlite3_bind_text(stmt, 7, instructions, -1, nil)
        sqlite3_bind_int(stmt, 8, Int32(recipeId))

        if sqlite3_step(stmt) != SQLITE_DONE {
            throw NSError(domain: "DB", code: 4,
                          userInfo: [NSLocalizedDescriptionKey: lastError()])
        }
    }
    // MARK: - Add Recipe

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

        try open()

        var cuisineId: Int? = nil

        // 1️⃣ Если указана кухня — получаем или создаём её
        if let cuisineName, !cuisineName.trimmingCharacters(in: .whitespaces).isEmpty {

            let existing: [Int] = try queryRows(
                "SELECT id FROM cuisines WHERE name = ? LIMIT 1;",
                parameters: [cuisineName]
            ) { $0[0] as? Int ?? 0 }

            if let id = existing.first {
                cuisineId = id
            } else {
                let insertCuisineSQL = "INSERT INTO cuisines(name) VALUES (?);"

                var cuisineStmt: OpaquePointer?
                if sqlite3_prepare_v2(db, insertCuisineSQL, -1, &cuisineStmt, nil) == SQLITE_OK {
                    sqlite3_bind_text(cuisineStmt, 1, cuisineName, -1, nil)
                    sqlite3_step(cuisineStmt)
                }
                sqlite3_finalize(cuisineStmt)

                cuisineId = Int(sqlite3_last_insert_rowid(db))
            }
        }

        // 2️⃣ Вставляем рецепт
        let sql = """
        INSERT INTO recipes
        (title, category_id, cuisine_id, difficulty,
         time_minutes, time_text, servings_text,
         instructions, is_archived)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0);
        """

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "DB", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: lastError()])
        }

        sqlite3_bind_text(stmt, 1, title, -1, nil)
        sqlite3_bind_int(stmt, 2, Int32(categoryId))

        if let cuisineId {
            sqlite3_bind_int(stmt, 3, Int32(cuisineId))
        } else {
            sqlite3_bind_null(stmt, 3)
        }

        sqlite3_bind_text(stmt, 4, difficulty, -1, nil)
        sqlite3_bind_int(stmt, 5, Int32(timeMinutes))
        sqlite3_bind_text(stmt, 6, "\(timeMinutes) мин", -1, nil)

        if let servingsText {
            sqlite3_bind_text(stmt, 7, servingsText, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 7)
        }

        sqlite3_bind_text(stmt, 8, instructions, -1, nil)

        if sqlite3_step(stmt) != SQLITE_DONE {
            throw NSError(domain: "DB", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: lastError()])
        }

        let recipeId = Int(sqlite3_last_insert_rowid(db))

        // 3️⃣ Добавляем ингредиенты
        for (index, line) in ingredientsLines.enumerated() {

            let parts = line
                .split(separator: "—", maxSplits: 1)
                .map { $0.trimmingCharacters(in: .whitespaces) }

            guard !parts.isEmpty else { continue }

            let ingredientName = parts[0]
            let amountText = parts.count > 1 ? parts[1] : ""

            // ищем ингредиент
            let existingIngredient: [Int] = try queryRows(
                "SELECT id FROM ingredients WHERE name = ? LIMIT 1;",
                parameters: [ingredientName]
            ) { $0[0] as? Int ?? 0 }

            var ingredientId: Int

            if let id = existingIngredient.first {
                ingredientId = id
            } else {
                var insertIngStmt: OpaquePointer?
                let insertIngSQL = "INSERT INTO ingredients(name) VALUES (?);"

                if sqlite3_prepare_v2(db, insertIngSQL, -1, &insertIngStmt, nil) == SQLITE_OK {
                    sqlite3_bind_text(insertIngStmt, 1, ingredientName, -1, nil)
                    sqlite3_step(insertIngStmt)
                }
                sqlite3_finalize(insertIngStmt)

                ingredientId = Int(sqlite3_last_insert_rowid(db))
            }

            // связываем с рецептом
            let linkSQL = """
            INSERT INTO recipe_ingredients
            (recipe_id, ingredient_id, amount_text, sort_order)
            VALUES (?, ?, ?, ?);
            """

            var linkStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, linkSQL, -1, &linkStmt, nil) == SQLITE_OK {

                sqlite3_bind_int(linkStmt, 1, Int32(recipeId))
                sqlite3_bind_int(linkStmt, 2, Int32(ingredientId))
                sqlite3_bind_text(linkStmt, 3, amountText, -1, nil)
                sqlite3_bind_int(linkStmt, 4, Int32(index))

                sqlite3_step(linkStmt)
            }

            sqlite3_finalize(linkStmt)
        }
    }

}
