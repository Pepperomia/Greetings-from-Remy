import Foundation
import SQLite3

// MARK: - Comments model

struct RecipeComment: Identifiable {
    let id: Int
    let text: String
    let createdAtISO: String

    var createdAtText: String {
        let s = createdAtISO.replacingOccurrences(of: "T", with: " ")
        return String(s.prefix(16))
    }
}

final class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: OpaquePointer?
    
    // ✅ ОДИН init, где вызываем создание индексов
    private init() {
        try? createAllIndices()
    }
    
    // MARK: - Open DB
    
    private func open() throws {
        if db != nil { return }
        
        let url = DatabaseBootstrap.appDatabaseURL()
        if sqlite3_open(url.path, &db) != SQLITE_OK {
            let msg = db.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "Unknown sqlite error"
            sqlite3_close(db)
            db = nil
            throw NSError(domain: "DB", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }
    
    // MARK: - Индексы для ускорения поиска
    
    private func createAllIndices() throws {
        try open()
        
        // Индексы для рецептов
        try execSQL("CREATE INDEX IF NOT EXISTS idx_recipes_title ON recipes(title);")
        try execSQL("CREATE INDEX IF NOT EXISTS idx_recipes_is_archived ON recipes(is_archived);")
        try execSQL("CREATE INDEX IF NOT EXISTS idx_recipes_category ON recipes(category_id);")
        try execSQL("CREATE INDEX IF NOT EXISTS idx_recipes_cuisine ON recipes(cuisine_id);")
        try execSQL("CREATE INDEX IF NOT EXISTS idx_recipes_time ON recipes(time_minutes);")
        try execSQL("CREATE INDEX IF NOT EXISTS idx_recipes_difficulty ON recipes(difficulty);")
        
        // Индексы для ингредиентов
        try execSQL("CREATE INDEX IF NOT EXISTS idx_ingredients_name ON ingredients(name);")
        try execSQL("CREATE INDEX IF NOT EXISTS idx_recipe_ingredients_recipe ON recipe_ingredients(recipe_id);")
        try execSQL("CREATE INDEX IF NOT EXISTS idx_recipe_ingredients_ingredient ON recipe_ingredients(ingredient_id);")
        
        // Индексы для кухонь и категорий
        try execSQL("CREATE INDEX IF NOT EXISTS idx_cuisines_name ON cuisines(name);")
        try execSQL("CREATE INDEX IF NOT EXISTS idx_categories_name ON categories(name);")
        
        print("✅ Все индексы созданы")
    }

    // MARK: - Open DB

    private func openDatabase() throws {
        if db != nil { return }

        let url = DatabaseBootstrap.appDatabaseURL()
        if sqlite3_open(url.path, &db) != SQLITE_OK {
            let msg = db.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "Unknown sqlite error"
            sqlite3_close(db)
            db = nil
            throw NSError(domain: "DB", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    // MARK: - Helpers

    private func lastError() -> String {
        guard let db else { return "DB is nil" }
        return String(cString: sqlite3_errmsg(db))
    }

    private func execSQL(_ sql: String) throws {
        try open()
        var errMsg: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            let msg = errMsg.map { String(cString: $0) } ?? lastError()
            sqlite3_free(errMsg)
            throw NSError(domain: "DB", code: 200, userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    private func begin() throws { try execSQL("BEGIN;") }
    private func commit() throws { try execSQL("COMMIT;") }
    private func rollback() { try? execSQL("ROLLBACK;") }

    private func bindText(_ stmt: OpaquePointer?, _ idx: Int32, _ value: String?) {
        if let value, !value.isEmpty {
            sqlite3_bind_text(stmt, idx, (value as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(stmt, idx)
        }
    }

    // MARK: - DB sanity

    func recipeCount() throws -> Int {
        try open()

        let sql = "SELECT COUNT(*) FROM recipes;"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "DB", code: 2, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }

        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }
        return 0
    }

    // MARK: - Recipe detail

    func fetchRecipeDetail(recipeId: Int) throws -> RecipeDetail {
        try open()

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

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "DB", code: 30, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }

        sqlite3_bind_int(stmt, 1, Int32(recipeId))

        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw NSError(domain: "DB", code: 31, userInfo: [NSLocalizedDescriptionKey: "Рецепт не найден"])
        }

        let id = Int(sqlite3_column_int(stmt, 0))
        let title = String(cString: sqlite3_column_text(stmt, 1))
        let categoryName = String(cString: sqlite3_column_text(stmt, 2))

        let cuisineName: String? = {
            if let ptr = sqlite3_column_text(stmt, 3) { return String(cString: ptr) }
            return nil
        }()

        let difficulty = String(cString: sqlite3_column_text(stmt, 4))
        let timeMinutes = Int(sqlite3_column_int(stmt, 5))

        let servingsText: String? = {
            if let ptr = sqlite3_column_text(stmt, 6) { return String(cString: ptr) }
            return nil
        }()

        let instructions = String(cString: sqlite3_column_text(stmt, 7))

        return RecipeDetail(
            id: id,
            title: title,
            categoryName: categoryName,
            cuisineName: cuisineName,
            difficulty: difficulty,
            timeMinutes: timeMinutes,
            servingsText: servingsText,
            instructions: instructions
        )
    }

    func fetchIngredients(recipeId: Int) throws -> [IngredientLine] {
        try open()

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

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "DB", code: 32, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }

        sqlite3_bind_int(stmt, 1, Int32(recipeId))

        var result: [IngredientLine] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(stmt, 0))
            let name = String(cString: sqlite3_column_text(stmt, 1))
            let amount = String(cString: sqlite3_column_text(stmt, 2))
            let sort = Int(sqlite3_column_int(stmt, 3))
            result.append(IngredientLine(id: id, name: name, amountText: amount, sortOrder: sort))
        }
        return result
    }

    // MARK: - User recipe data (favorites + cooked)

    func fetchUserRecipeData(recipeId: Int) throws -> UserRecipeData {
        try open()

        let sql = """
        SELECT recipe_id, is_favorite, cooked_count
        FROM user_recipe_data
        WHERE recipe_id = ?
        LIMIT 1;
        """

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "DB", code: 40, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }

        sqlite3_bind_int(stmt, 1, Int32(recipeId))

        if sqlite3_step(stmt) == SQLITE_ROW {
            let rid = Int(sqlite3_column_int(stmt, 0))
            let fav = Int(sqlite3_column_int(stmt, 1)) != 0
            let cnt = Int(sqlite3_column_int(stmt, 2))
            return UserRecipeData(recipeId: rid, isFavorite: fav, cookedCount: cnt)
        }

        // если строки нет — создадим
        var ins: OpaquePointer?
        defer { sqlite3_finalize(ins) }

        if sqlite3_prepare_v2(db, "INSERT OR IGNORE INTO user_recipe_data(recipe_id) VALUES (?);", -1, &ins, nil) != SQLITE_OK {
            throw NSError(domain: "DB", code: 41, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }

        sqlite3_bind_int(ins, 1, Int32(recipeId))
        _ = sqlite3_step(ins)

        return UserRecipeData(recipeId: recipeId, isFavorite: false, cookedCount: 0)
    }

    func setFavorite(recipeId: Int, isFavorite: Bool) throws {
        try open()

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        let sql = "UPDATE user_recipe_data SET is_favorite = ? WHERE recipe_id = ?;"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "DB", code: 42, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }

        sqlite3_bind_int(stmt, 1, isFavorite ? 1 : 0)
        sqlite3_bind_int(stmt, 2, Int32(recipeId))

        if sqlite3_step(stmt) != SQLITE_DONE {
            throw NSError(domain: "DB", code: 43, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }
    }

    func incrementCookedCount(recipeId: Int) throws {
        try open()

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        let sql = """
        UPDATE user_recipe_data
        SET cooked_count = cooked_count + 1,
            last_cooked_at = datetime('now')
        WHERE recipe_id = ?;
        """
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "DB", code: 44, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }

        sqlite3_bind_int(stmt, 1, Int32(recipeId))

        if sqlite3_step(stmt) != SQLITE_DONE {
            throw NSError(domain: "DB", code: 45, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }
    }

    func fetchFavoriteRecipes() throws -> [RecipeRow] {
        try open()

        let sql = """
        SELECT r.id, r.title, r.time_minutes, r.difficulty
        FROM recipes r
        JOIN user_recipe_data u ON u.recipe_id = r.id
        WHERE r.is_archived = 0 AND u.is_favorite = 1
        ORDER BY r.title;
        """

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "DB", code: 46, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }

        var result: [RecipeRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(stmt, 0))
            let title = String(cString: sqlite3_column_text(stmt, 1))
            let time = Int(sqlite3_column_int(stmt, 2))
            let diff = String(cString: sqlite3_column_text(stmt, 3))
            result.append(RecipeRow(id: id, title: title, timeMinutes: time, difficulty: diff))
        }
        return result
    }

    // MARK: - Cuisines
    // ВАЖНО: без нормализации. Берём только кухни, у которых реально есть рецепты.
    // Плюс: можно легко "временно" отфильтровать те, что начинаются с маленькой буквы.

    func fetchCuisines() throws -> [CuisineRow] {
        try open()

        let sql = """
        SELECT cu.id, cu.name
        FROM cuisines cu
        WHERE EXISTS (
            SELECT 1
            FROM recipes r
            WHERE r.cuisine_id = cu.id AND r.is_archived = 0
        )
        ORDER BY lower(trim(cu.name));
        """

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "DB", code: 710, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }

        var result: [CuisineRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(stmt, 0))
            let name = String(cString: sqlite3_column_text(stmt, 1))
            result.append(CuisineRow(id: id, name: name))
        }
        return result
    }
    
    // MARK: - Cuisines: Add + FetchAll

    func fetchAllCuisines() throws -> [CuisineRow] {
        try open()

        let sql = """
        SELECT id, name
        FROM cuisines
        ORDER BY lower(trim(name));
        """

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "DB", code: 711, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }

        var result: [CuisineRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(stmt, 0))
            let name = String(cString: sqlite3_column_text(stmt, 1))
            result.append(CuisineRow(id: id, name: name))
        }
        return result
    }

    @discardableResult
    func addCuisine(name: String) throws -> Int {
        try open()

        let raw = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            throw NSError(domain: "DB", code: 712, userInfo: [NSLocalizedDescriptionKey: "Название кухни не может быть пустым"])
        }

        // “красиво”: trim + первая буква заглавная (простое правило)
        let clean: String = {
            let t = raw.replacingOccurrences(of: "  ", with: " ")
            guard let first = t.first else { return t }
            return String(first).uppercased() + t.dropFirst()
        }()

        // Если уже есть (без учёта регистра/пробелов) — просто вернём id
        var sel: OpaquePointer?
        defer { sqlite3_finalize(sel) }

        let selSQL = "SELECT id FROM cuisines WHERE lower(trim(name)) = lower(trim(?)) LIMIT 1;"
        if sqlite3_prepare_v2(db, selSQL, -1, &sel, nil) != SQLITE_OK {
            throw NSError(domain: "DB", code: 713, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }
        sqlite3_bind_text(sel, 1, (clean as NSString).utf8String, -1, nil)

        if sqlite3_step(sel) == SQLITE_ROW {
            return Int(sqlite3_column_int(sel, 0))
        }

        // Иначе вставим
        var ins: OpaquePointer?
        defer { sqlite3_finalize(ins) }

        let insSQL = "INSERT INTO cuisines(name) VALUES (?);"
        if sqlite3_prepare_v2(db, insSQL, -1, &ins, nil) != SQLITE_OK {
            throw NSError(domain: "DB", code: 714, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }
        sqlite3_bind_text(ins, 1, (clean as NSString).utf8String, -1, nil)

        if sqlite3_step(ins) != SQLITE_DONE {
            throw NSError(domain: "DB", code: 715, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }

        return Int(sqlite3_last_insert_rowid(db))
    }

    // MARK: - Categories

    func fetchCategories() throws -> [CategoryRow] {
        try open()

        let sql = """
        SELECT c.id, c.name, COUNT(r.id) as cnt
        FROM categories c
        LEFT JOIN recipes r ON r.category_id = c.id AND r.is_archived = 0
        GROUP BY c.id, c.name
        ORDER BY c.sort_order, c.name;
        """

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "DB", code: 3, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }

        var result: [CategoryRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(stmt, 0))
            let name = String(cString: sqlite3_column_text(stmt, 1))
            let cnt = Int(sqlite3_column_int(stmt, 2))
            result.append(CategoryRow(id: id, name: name, count: cnt))
        }
        return result
    }

    func fetchRecipes(categoryId: Int) throws -> [RecipeRow] {
        try open()

        let sql = """
        SELECT id, title, time_minutes, difficulty
        FROM recipes
        WHERE category_id = ? AND is_archived = 0
        ORDER BY title;
        """

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "DB", code: 4, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }

        sqlite3_bind_int(stmt, 1, Int32(categoryId))

        var result: [RecipeRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(stmt, 0))
            let title = String(cString: sqlite3_column_text(stmt, 1))
            let time = Int(sqlite3_column_int(stmt, 2))
            let diff = String(cString: sqlite3_column_text(stmt, 3))
            result.append(RecipeRow(id: id, title: title, timeMinutes: time, difficulty: diff))
        }
        return result
    }
    
    func mergeCategory(oldName: String, into newName: String) throws {
        try open()
        try begin()
        do {
            // 1) найти/создать целевую категорию
            let newId: Int = try {
                var stmt: OpaquePointer?
                defer { sqlite3_finalize(stmt) }

                let sql = "SELECT id FROM categories WHERE trim(name)=trim(?) LIMIT 1;"
                if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
                    throw NSError(domain: "DB", code: 9001, userInfo: [NSLocalizedDescriptionKey: lastError()])
                }
                sqlite3_bind_text(stmt, 1, (newName as NSString).utf8String, -1, nil)

                if sqlite3_step(stmt) == SQLITE_ROW {
                    return Int(sqlite3_column_int(stmt, 0))
                }

                // нет — создаём
                var ins: OpaquePointer?
                defer { sqlite3_finalize(ins) }
                if sqlite3_prepare_v2(db, "INSERT INTO categories(name, sort_order) VALUES (?, 40);", -1, &ins, nil) != SQLITE_OK {
                    throw NSError(domain: "DB", code: 9002, userInfo: [NSLocalizedDescriptionKey: lastError()])
                }
                sqlite3_bind_text(ins, 1, (newName as NSString).utf8String, -1, nil)
                if sqlite3_step(ins) != SQLITE_DONE {
                    throw NSError(domain: "DB", code: 9003, userInfo: [NSLocalizedDescriptionKey: lastError()])
                }
                return Int(sqlite3_last_insert_rowid(db))
            }()

            // 2) собрать ВСЕ oldId (может быть несколько дублей старого имени)
            var oldIds: [Int] = []
            do {
                var stmt: OpaquePointer?
                defer { sqlite3_finalize(stmt) }

                let sql = "SELECT id FROM categories WHERE trim(name)=trim(?)"
                if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
                    throw NSError(domain: "DB", code: 9004, userInfo: [NSLocalizedDescriptionKey: lastError()])
                }
                sqlite3_bind_text(stmt, 1, (oldName as NSString).utf8String, -1, nil)

                while sqlite3_step(stmt) == SQLITE_ROW {
                    oldIds.append(Int(sqlite3_column_int(stmt, 0)))
                }
            }

            // нечего мёрджить
            if oldIds.isEmpty {
                try commit()
                return
            }

            // 3) перенести recipes.category_id -> newId
            for oldId in oldIds where oldId != newId {
                try execSQL("UPDATE recipes SET category_id = \(newId) WHERE category_id = \(oldId);")
            }

            // 4) удалить старые категории (кроме newId)
            for oldId in oldIds where oldId != newId {
                try execSQL("DELETE FROM categories WHERE id = \(oldId);")
            }

            // 5) подчистить пробелы
            try execSQL("UPDATE categories SET name = trim(name);")

            try commit()
        } catch {
            rollback()
            throw error
        }
    }

    func fixCategoryDuplicatesForUI() throws {
        // Горячее (основное) -> Горячее
        try mergeCategory(oldName: "Горячее (основное)", into: "Горячее")

        // Горячее (гарниры) -> Гарниры
        try mergeCategory(oldName: "Горячее (гарниры)", into: "Гарниры")
    }
    
    func renameCategoriesForUI() throws {
        try open()
        try begin()
        do {
            // 1) Переименовать категории
            try execSQL("""
            UPDATE categories
            SET name = 'Горячее'
            WHERE trim(name) = 'Горячее (основное)';
            """)

            try execSQL("""
            UPDATE categories
            SET name = 'Гарниры'
            WHERE trim(name) = 'Горячее (гарниры)';
            """)

            // 2) На всякий: убрать лишние пробелы
            try execSQL("UPDATE categories SET name = trim(name);")

            try commit()
        } catch {
            rollback()
            throw error
        }
    }

    // MARK: - Search (FIXED: bind order)

    func searchRecipes(
        query: String,
        categoryId: Int?,
        cuisineId: Int?,
        maxMinutes: Int?,
        onlyEasy: Bool
    ) throws -> [RecipeRow] {
        try open()

        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)

        let baseSQL = """
        SELECT r.id, r.title, r.time_minutes, r.difficulty
        FROM recipes r
        LEFT JOIN recipe_ingredients ri ON ri.recipe_id = r.id
        LEFT JOIN ingredients i ON i.id = ri.ingredient_id
        LEFT JOIN recipe_tags rt ON rt.recipe_id = r.id
        LEFT JOIN tags t ON t.id = rt.tag_id
        """

        // порядок условий = порядок биндов
        var conditions: [String] = ["r.is_archived = 0"]
        if categoryId != nil { conditions.append("r.category_id = ?") }
        if cuisineId != nil { conditions.append("r.cuisine_id = ?") }
        if !q.isEmpty { conditions.append("(r.title LIKE ? OR i.name LIKE ? OR t.name LIKE ?)") }
        if maxMinutes != nil { conditions.append("r.time_minutes <= ?") }
        if onlyEasy { conditions.append("r.difficulty = 'easy'") }

        let whereSQL = "WHERE " + conditions.joined(separator: " AND ")

        let tailSQL = """
        GROUP BY r.id
        ORDER BY r.title
        LIMIT 50;
        """

        let sql = baseSQL + "\n" + whereSQL + "\n" + tailSQL

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "DB", code: 10, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }

        var bindIndex: Int32 = 1

        if let categoryId {
            sqlite3_bind_int(stmt, bindIndex, Int32(categoryId))
            bindIndex += 1
        }

        if let cuisineId {
            sqlite3_bind_int(stmt, bindIndex, Int32(cuisineId))
            bindIndex += 1
        }

        if !q.isEmpty {
            let pattern = ("%\(q)%") as NSString
            sqlite3_bind_text(stmt, bindIndex, pattern.utf8String, -1, nil); bindIndex += 1
            sqlite3_bind_text(stmt, bindIndex, pattern.utf8String, -1, nil); bindIndex += 1
            sqlite3_bind_text(stmt, bindIndex, pattern.utf8String, -1, nil); bindIndex += 1
        }

        if let maxMinutes {
            sqlite3_bind_int(stmt, bindIndex, Int32(maxMinutes))
            bindIndex += 1
        }

        var result: [RecipeRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(stmt, 0))
            let title = String(cString: sqlite3_column_text(stmt, 1))
            let time = Int(sqlite3_column_int(stmt, 2))
            let diff = String(cString: sqlite3_column_text(stmt, 3))
            result.append(RecipeRow(id: id, title: title, timeMinutes: time, difficulty: diff))
        }

        return result
    }

    // MARK: - Random (FIXED: bind order)

    func randomRecipeId(
        query: String,
        categoryId: Int?,
        cuisineId: Int?,
        maxMinutes: Int?,
        onlyEasy: Bool
    ) throws -> Int? {
        try open()

        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)

        let baseSQL = """
        SELECT r.id
        FROM recipes r
        LEFT JOIN recipe_ingredients ri ON ri.recipe_id = r.id
        LEFT JOIN ingredients i ON i.id = ri.ingredient_id
        LEFT JOIN recipe_tags rt ON rt.recipe_id = r.id
        LEFT JOIN tags t ON t.id = rt.tag_id
        """

        // порядок условий = порядок биндов
        var conditions: [String] = ["r.is_archived = 0"]
        if categoryId != nil { conditions.append("r.category_id = ?") }
        if cuisineId != nil { conditions.append("r.cuisine_id = ?") }
        if !q.isEmpty { conditions.append("(r.title LIKE ? OR i.name LIKE ? OR t.name LIKE ?)") }
        if maxMinutes != nil { conditions.append("r.time_minutes <= ?") }
        if onlyEasy { conditions.append("r.difficulty = 'easy'") }

        let whereSQL = "WHERE " + conditions.joined(separator: " AND ")

        let sql = baseSQL + "\n" + whereSQL + "\n" + """
        GROUP BY r.id
        ORDER BY RANDOM()
        LIMIT 1;
        """

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "DB", code: 20, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }

        var bindIndex: Int32 = 1

        if let categoryId {
            sqlite3_bind_int(stmt, bindIndex, Int32(categoryId))
            bindIndex += 1
        }

        if let cuisineId {
            sqlite3_bind_int(stmt, bindIndex, Int32(cuisineId))
            bindIndex += 1
        }

        if !q.isEmpty {
            let pattern = ("%\(q)%") as NSString
            sqlite3_bind_text(stmt, bindIndex, pattern.utf8String, -1, nil); bindIndex += 1
            sqlite3_bind_text(stmt, bindIndex, pattern.utf8String, -1, nil); bindIndex += 1
            sqlite3_bind_text(stmt, bindIndex, pattern.utf8String, -1, nil); bindIndex += 1
        }

        if let maxMinutes {
            sqlite3_bind_int(stmt, bindIndex, Int32(maxMinutes))
            bindIndex += 1
        }

        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }
        return nil
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
        try open()

        func norm(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }

        let cleanTitle = norm(title)
        if cleanTitle.isEmpty {
            throw NSError(domain: "DB", code: 100, userInfo: [NSLocalizedDescriptionKey: "Название не может быть пустым"])
        }

        try begin()
        do {
            let cuisineId = try ensureCuisineId(name: cuisineName)

            let insertRecipeSQL = """
            INSERT INTO recipes (title, category_id, cuisine_id, difficulty, time_minutes, servings_text, instructions)
            VALUES (?, ?, ?, ?, ?, ?, ?);
            """

            var insertRecipe: OpaquePointer?
            defer { sqlite3_finalize(insertRecipe) }

            if sqlite3_prepare_v2(db, insertRecipeSQL, -1, &insertRecipe, nil) != SQLITE_OK {
                throw NSError(domain: "DB", code: 103, userInfo: [NSLocalizedDescriptionKey: lastError()])
            }

            sqlite3_bind_text(insertRecipe, 1, (cleanTitle as NSString).utf8String, -1, nil)
            sqlite3_bind_int(insertRecipe, 2, Int32(categoryId))

            if let cuisineId {
                sqlite3_bind_int(insertRecipe, 3, Int32(cuisineId))
            } else {
                sqlite3_bind_null(insertRecipe, 3)
            }

            sqlite3_bind_text(insertRecipe, 4, (difficulty as NSString).utf8String, -1, nil)
            sqlite3_bind_int(insertRecipe, 5, Int32(timeMinutes))
            bindText(insertRecipe, 6, norm(servingsText ?? ""))
            sqlite3_bind_text(insertRecipe, 7, (instructions as NSString).utf8String, -1, nil)

            if sqlite3_step(insertRecipe) != SQLITE_DONE {
                throw NSError(domain: "DB", code: 104, userInfo: [NSLocalizedDescriptionKey: lastError()])
            }

            let newRecipeId = Int(sqlite3_last_insert_rowid(db))

            var insUser: OpaquePointer?
            defer { sqlite3_finalize(insUser) }
            if sqlite3_prepare_v2(db, "INSERT OR IGNORE INTO user_recipe_data(recipe_id) VALUES (?);", -1, &insUser, nil) != SQLITE_OK {
                throw NSError(domain: "DB", code: 105, userInfo: [NSLocalizedDescriptionKey: lastError()])
            }
            sqlite3_bind_int(insUser, 1, Int32(newRecipeId))
            _ = sqlite3_step(insUser)

            try replaceIngredients(recipeId: newRecipeId, ingredientsLines: ingredientsLines)

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
        try open()

        try begin()
        do {
            let cuisineId = try ensureCuisineId(name: cuisineName)

            let sql = """
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

            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
                throw NSError(domain: "DB", code: 401, userInfo: [NSLocalizedDescriptionKey: lastError()])
            }

            sqlite3_bind_text(stmt, 1, (title as NSString).utf8String, -1, nil)
            sqlite3_bind_int(stmt, 2, Int32(categoryId))

            if let cuisineId {
                sqlite3_bind_int(stmt, 3, Int32(cuisineId))
            } else {
                sqlite3_bind_null(stmt, 3)
            }

            sqlite3_bind_text(stmt, 4, (difficulty as NSString).utf8String, -1, nil)
            sqlite3_bind_int(stmt, 5, Int32(timeMinutes))
            bindText(stmt, 6, servingsText)
            sqlite3_bind_text(stmt, 7, (instructions as NSString).utf8String, -1, nil)
            sqlite3_bind_int(stmt, 8, Int32(recipeId))

            if sqlite3_step(stmt) != SQLITE_DONE {
                throw NSError(domain: "DB", code: 402, userInfo: [NSLocalizedDescriptionKey: lastError()])
            }

            try replaceIngredients(recipeId: recipeId, ingredientsLines: ingredientsLines)

            try commit()
        } catch {
            rollback()
            throw error
        }
    }

    func archiveRecipe(recipeId: Int) throws {
        try open()
        try execSQL("UPDATE recipes SET is_archived = 1 WHERE id = \(recipeId);")
    }

    // MARK: - Comments

    private func ensureCommentsTable() throws {
        try open()
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

    func fetchComments(recipeId: Int) throws -> [RecipeComment] {
        try ensureCommentsTable()

        let sql = """
        SELECT id, text, created_at
        FROM recipe_comments
        WHERE recipe_id = ?
        ORDER BY id DESC;
        """

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "DB", code: 301, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }

        sqlite3_bind_int(stmt, 1, Int32(recipeId))

        var result: [RecipeComment] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(stmt, 0))
            let text = String(cString: sqlite3_column_text(stmt, 1))
            let created = String(cString: sqlite3_column_text(stmt, 2))
            result.append(RecipeComment(id: id, text: text, createdAtISO: created))
        }
        return result
    }

    func addComment(recipeId: Int, text: String) throws {
        try ensureCommentsTable()

        let sql = "INSERT INTO recipe_comments(recipe_id, text) VALUES (?, ?);"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "DB", code: 302, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }

        sqlite3_bind_int(stmt, 1, Int32(recipeId))
        sqlite3_bind_text(stmt, 2, (text as NSString).utf8String, -1, nil)

        if sqlite3_step(stmt) != SQLITE_DONE {
            throw NSError(domain: "DB", code: 303, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }
    }
    
    // MARK: - Comments (edit / delete)

    func updateComment(commentId: Int, text: String) throws {
        try ensureCommentsTable()

        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            throw NSError(domain: "DB", code: 304, userInfo: [NSLocalizedDescriptionKey: "Комментарий не может быть пустым"])
        }

        let sql = "UPDATE recipe_comments SET text = ? WHERE id = ?;"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "DB", code: 305, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }

        sqlite3_bind_text(stmt, 1, (clean as NSString).utf8String, -1, nil)
        sqlite3_bind_int(stmt, 2, Int32(commentId))

        if sqlite3_step(stmt) != SQLITE_DONE {
            throw NSError(domain: "DB", code: 306, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }
    }

    func deleteComment(commentId: Int) throws {
        try ensureCommentsTable()

        let sql = "DELETE FROM recipe_comments WHERE id = ?;"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "DB", code: 307, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }

        sqlite3_bind_int(stmt, 1, Int32(commentId))

        if sqlite3_step(stmt) != SQLITE_DONE {
            throw NSError(domain: "DB", code: 308, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }
    }

    // MARK: - Initial taxonomy (чтоб ContentView не ругался)

    func ensureInitialTaxonomy() throws {
        try open()

        // категории (безопасно: не создаст дублей)
        try execSQL("INSERT OR IGNORE INTO categories(name, sort_order) VALUES ('Завтраки', 10);")
        try execSQL("INSERT OR IGNORE INTO categories(name, sort_order) VALUES ('Салаты', 20);")
        try execSQL("INSERT OR IGNORE INTO categories(name, sort_order) VALUES ('Супы', 30);")
        try execSQL("INSERT OR IGNORE INTO categories(name, sort_order) VALUES ('Горячее (основное)', 40);")
        try execSQL("INSERT OR IGNORE INTO categories(name, sort_order) VALUES ('Горячее (гарниры)', 50);")
        try execSQL("INSERT OR IGNORE INTO categories(name, sort_order) VALUES ('Выпечка', 60);")
        try execSQL("INSERT OR IGNORE INTO categories(name, sort_order) VALUES ('Закуски', 70);")
        try execSQL("INSERT OR IGNORE INTO categories(name, sort_order) VALUES ('Десерты', 80);")
        try execSQL("INSERT OR IGNORE INTO categories(name, sort_order) VALUES ('Напитки', 90);")

        // пару базовых кухонь (не обязательно)
        try execSQL("INSERT OR IGNORE INTO cuisines(name) VALUES ('Русская');")
        try execSQL("INSERT OR IGNORE INTO cuisines(name) VALUES ('Европейская');")
        try execSQL("INSERT OR IGNORE INTO cuisines(name) VALUES ('Итальянская');")
        try execSQL("INSERT OR IGNORE INTO cuisines(name) VALUES ('Греческая');")
        try execSQL("INSERT OR IGNORE INTO cuisines(name) VALUES ('Азиатская');")
    }

    // MARK: - Internal: cuisine + ingredients helpers

    private func ensureCuisineId(name: String?) throws -> Int? {
        let clean = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if clean.isEmpty { return nil }

        var ins: OpaquePointer?
        defer { sqlite3_finalize(ins) }
        if sqlite3_prepare_v2(db, "INSERT OR IGNORE INTO cuisines(name) VALUES (?);", -1, &ins, nil) != SQLITE_OK {
            throw NSError(domain: "DB", code: 501, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }
        sqlite3_bind_text(ins, 1, (clean as NSString).utf8String, -1, nil)
        _ = sqlite3_step(ins)

        var sel: OpaquePointer?
        defer { sqlite3_finalize(sel) }
        if sqlite3_prepare_v2(db, "SELECT id FROM cuisines WHERE lower(trim(name)) = lower(trim(?)) LIMIT 1;", -1, &sel, nil) != SQLITE_OK {
            throw NSError(domain: "DB", code: 502, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }
        sqlite3_bind_text(sel, 1, (clean as NSString).utf8String, -1, nil)

        if sqlite3_step(sel) == SQLITE_ROW {
            return Int(sqlite3_column_int(sel, 0))
        }
        return nil
    }

    private func getOrCreateIngredientId(name: String) throws -> Int {
        try open()
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            throw NSError(domain: "DB", code: 610, userInfo: [NSLocalizedDescriptionKey: "Пустой ингредиент"])
        }

        var sel: OpaquePointer?
        defer { sqlite3_finalize(sel) }
        if sqlite3_prepare_v2(db, "SELECT id FROM ingredients WHERE lower(name)=lower(?) LIMIT 1;", -1, &sel, nil) != SQLITE_OK {
            throw NSError(domain: "DB", code: 611, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }
        sqlite3_bind_text(sel, 1, (clean as NSString).utf8String, -1, nil)
        if sqlite3_step(sel) == SQLITE_ROW {
            return Int(sqlite3_column_int(sel, 0))
        }

        var ins: OpaquePointer?
        defer { sqlite3_finalize(ins) }
        if sqlite3_prepare_v2(db, "INSERT INTO ingredients(name) VALUES (?);", -1, &ins, nil) != SQLITE_OK {
            throw NSError(domain: "DB", code: 612, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }
        sqlite3_bind_text(ins, 1, (clean as NSString).utf8String, -1, nil)
        if sqlite3_step(ins) != SQLITE_DONE {
            throw NSError(domain: "DB", code: 613, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }
        return Int(sqlite3_last_insert_rowid(db))
    }

    private func replaceIngredients(recipeId: Int, ingredientsLines: [String]) throws {
        try open()
        try execSQL("DELETE FROM recipe_ingredients WHERE recipe_id = \(recipeId);")

        func norm(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }

        for (idx, line) in ingredientsLines.enumerated() {
            let raw = norm(line)
            if raw.isEmpty { continue }

            let cleaned = raw.replacingOccurrences(of: " - ", with: " — ")
            let parts = cleaned.split(separator: "—", maxSplits: 1).map { norm(String($0)) }

            let ingName = parts.first ?? ""
            if ingName.isEmpty { continue }

            let amount = parts.count > 1 ? parts[1] : "по вкусу"
            let ingId = try getOrCreateIngredientId(name: ingName)

            let ins = "INSERT INTO recipe_ingredients(recipe_id, ingredient_id, amount_text, sort_order) VALUES (?, ?, ?, ?);"
            var st: OpaquePointer?
            defer { sqlite3_finalize(st) }

            if sqlite3_prepare_v2(db, ins, -1, &st, nil) != SQLITE_OK {
                throw NSError(domain: "DB", code: 620, userInfo: [NSLocalizedDescriptionKey: lastError()])
            }

            sqlite3_bind_int(st, 1, Int32(recipeId))
            sqlite3_bind_int(st, 2, Int32(ingId))
            sqlite3_bind_text(st, 3, (amount as NSString).utf8String, -1, nil)
            sqlite3_bind_int(st, 4, Int32(idx))

            if sqlite3_step(st) != SQLITE_DONE {
                throw NSError(domain: "DB", code: 621, userInfo: [NSLocalizedDescriptionKey: lastError()])
            }
        }
    }
    
    func normalizeCategoriesForUI() throws {
        try open()
        try begin()
        do {
            // 1) создать/найти канонические категории
            func ensureCategoryId(_ name: String, sort: Int) throws -> Int {
                // есть?
                var sel: OpaquePointer?
                defer { sqlite3_finalize(sel) }
                if sqlite3_prepare_v2(db, "SELECT id FROM categories WHERE trim(name)=trim(?) LIMIT 1;", -1, &sel, nil) != SQLITE_OK {
                    throw NSError(domain: "DB", code: 9101, userInfo: [NSLocalizedDescriptionKey: lastError()])
                }
                sqlite3_bind_text(sel, 1, (name as NSString).utf8String, -1, nil)
                if sqlite3_step(sel) == SQLITE_ROW {
                    return Int(sqlite3_column_int(sel, 0))
                }

                // нет -> создаём
                var ins: OpaquePointer?
                defer { sqlite3_finalize(ins) }
                if sqlite3_prepare_v2(db, "INSERT INTO categories(name, sort_order) VALUES (?, ?);", -1, &ins, nil) != SQLITE_OK {
                    throw NSError(domain: "DB", code: 9102, userInfo: [NSLocalizedDescriptionKey: lastError()])
                }
                sqlite3_bind_text(ins, 1, (name as NSString).utf8String, -1, nil)
                sqlite3_bind_int(ins, 2, Int32(sort))
                if sqlite3_step(ins) != SQLITE_DONE {
                    throw NSError(domain: "DB", code: 9103, userInfo: [NSLocalizedDescriptionKey: lastError()])
                }
                return Int(sqlite3_last_insert_rowid(db))
            }

            let hotId = try ensureCategoryId("Горячее", sort: 40)
            let sidesId = try ensureCategoryId("Гарниры", sort: 50)

            // 2) собрать id дублей
            func ids(for name: String) throws -> [Int] {
                var stmt: OpaquePointer?
                defer { sqlite3_finalize(stmt) }
                if sqlite3_prepare_v2(db, "SELECT id FROM categories WHERE trim(name)=trim(?);", -1, &stmt, nil) != SQLITE_OK {
                    throw NSError(domain: "DB", code: 9104, userInfo: [NSLocalizedDescriptionKey: lastError()])
                }
                sqlite3_bind_text(stmt, 1, (name as NSString).utf8String, -1, nil)

                var res: [Int] = []
                while sqlite3_step(stmt) == SQLITE_ROW {
                    res.append(Int(sqlite3_column_int(stmt, 0)))
                }
                return res
            }

            let hotMainIds = try ids(for: "Горячее (основное)")
            let hotSidesIds = try ids(for: "Горячее (гарниры)")

            // 3) перенос рецептов на канон
            if !hotMainIds.isEmpty {
                let list = hotMainIds.map(String.init).joined(separator: ",")
                try execSQL("UPDATE recipes SET category_id = \(hotId) WHERE category_id IN (\(list));")
            }
            if !hotSidesIds.isEmpty {
                let list = hotSidesIds.map(String.init).joined(separator: ",")
                try execSQL("UPDATE recipes SET category_id = \(sidesId) WHERE category_id IN (\(list));")
            }

            // 4) удалить старые категории (теперь они пустые)
            let toDelete = (hotMainIds + hotSidesIds).filter { $0 != hotId && $0 != sidesId }
            if !toDelete.isEmpty {
                let list = toDelete.map(String.init).joined(separator: ",")
                try execSQL("DELETE FROM categories WHERE id IN (\(list));")
            }

            // 5) подчистить пробелы
            try execSQL("UPDATE categories SET name = trim(name);")

            try commit()
        } catch {
            rollback()
            throw error
        }
    }

    // MARK: - Query Helpers

    private func runQuery<T>(
        _ sql: String,
        parameters: [Any] = [],
        mapRow: (SQLiteRow) -> T
    ) throws -> [T] {
        try open()
        
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw NSError(domain: "DB", code: 1000, userInfo: [NSLocalizedDescriptionKey: lastError()])
        }
        
        // Биндим параметры
        for (idx, param) in parameters.enumerated() {
            let bindIdx = Int32(idx + 1)
            
            if let intParam = param as? Int {
                sqlite3_bind_int(stmt, bindIdx, Int32(intParam))
            } else if let stringParam = param as? String {
                sqlite3_bind_text(stmt, bindIdx, (stringParam as NSString).utf8String, -1, nil)
            } else if let doubleParam = param as? Double {
                sqlite3_bind_double(stmt, bindIdx, doubleParam)
            } else if param is NSNull {
                sqlite3_bind_null(stmt, bindIdx)
            }
        }
        
        var results: [T] = []
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            let row = SQLiteRow(statement: stmt)
            results.append(mapRow(row))
        }
        
        return results
    }

    // MARK: - SQLiteRow Helper

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
            case SQLITE_NULL:
                return nil
            default:
                return nil
            }
        }
    }
}

// MARK: - DatabaseManager Extensions для SearchView

extension DatabaseManager {
    
    // Поиск названий ингредиентов по префиксу (для автодополнения)
    func searchIngredientNames(prefix: String) throws -> [String] {
        let sql = """
            SELECT DISTINCT name 
            FROM ingredients 
            WHERE name LIKE ? 
            ORDER BY name 
            LIMIT 10
        """
        
        let pattern = "\(prefix)%"
        let resultMap: (SQLiteRow) -> String = { row in
            return row[0] as? String ?? ""
        }
        
        return try runQuery(sql, parameters: [pattern], mapRow: resultMap)
            .filter { !$0.isEmpty }
    }
    
    // Получение популярных ингредиентов
    func getPopularIngredients(limit: Int) throws -> [String] {
        let sql = """
            SELECT i.name, COUNT(*) as count
            FROM ingredients i
            GROUP BY i.name
            ORDER BY count DESC, i.name
            LIMIT ?
        """
        
        let resultMap: (SQLiteRow) -> String = { row in
            return row[0] as? String ?? ""
        }
        
        return try runQuery(sql, parameters: [limit], mapRow: resultMap)
            .filter { !$0.isEmpty }
    }
    
    // Обновленный поиск рецептов с учетом нескольких ингредиентов
    // В DatabaseManager, замени метод searchRecipes на эту версию
    func searchRecipes(
        query: String,
        ingredients: [String]? = nil,
        categoryId: Int? = nil,
        cuisineId: Int? = nil,
        maxMinutes: Int? = nil,
        onlyEasy: Bool = false
    ) throws -> [RecipeRow] {
        
        try open()
        
        var sql = """
            SELECT DISTINCT r.id, r.title, r.time_minutes, r.difficulty
            FROM recipes r
        """
        
        var parameters: [Any] = []
        var joins = ""
        var whereClauses = ["r.is_archived = 0"]
        
        // Добавляем JOIN только если нужен поиск по ингредиентам
        if let ingredients = ingredients, !ingredients.isEmpty {
            joins += """
                JOIN recipe_ingredients ri ON r.id = ri.recipe_id
                JOIN ingredients i ON ri.ingredient_id = i.id
            """
            
            let placeholders = Array(repeating: "?", count: ingredients.count).joined(separator: ",")
            whereClauses.append("""
                r.id IN (
                    SELECT recipe_id 
                    FROM recipe_ingredients ri2
                    JOIN ingredients i2 ON ri2.ingredient_id = i2.id
                    WHERE i2.name IN (\(placeholders))
                    GROUP BY recipe_id
                    HAVING COUNT(DISTINCT i2.name) = ?
                )
            """)
            
            parameters.append(contentsOf: ingredients)
            parameters.append(ingredients.count)
        }
        
        // Поиск по названию
        if !query.isEmpty {
            whereClauses.append("r.title LIKE ?")
            parameters.append("%\(query)%")
        }
        
        // Фильтры
        if let categoryId = categoryId {
            whereClauses.append("r.category_id = ?")
            parameters.append(categoryId)
        }
        
        if let cuisineId = cuisineId {
            whereClauses.append("r.cuisine_id = ?")
            parameters.append(cuisineId)
        }
        
        if let maxMinutes = maxMinutes {
            whereClauses.append("r.time_minutes <= ?")
            parameters.append(maxMinutes)
        }
        
        if onlyEasy {
            whereClauses.append("r.difficulty = 'easy'")
        }
        
        // Собираем запрос
        sql += joins
        sql += " WHERE " + whereClauses.joined(separator: " AND ")
        sql += " GROUP BY r.id ORDER BY r.title LIMIT 50"
        
        let resultMap: (SQLiteRow) -> RecipeRow = { row in
            RecipeRow(
                id: row[0] as? Int ?? 0,
                title: row[1] as? String ?? "",
                timeMinutes: row[2] as? Int ?? 0,
                difficulty: row[3] as? String ?? "medium"
            )
        }
        
        return try runQuery(sql, parameters: parameters, mapRow: resultMap)
    }
    
    // Случайный рецепт с фильтрами
    func randomRecipeId(
        query: String,
        ingredients: [String]? = nil,
        categoryId: Int? = nil,
        cuisineId: Int? = nil,
        maxMinutes: Int? = nil,
        onlyEasy: Bool = false
    ) throws -> Int? {
        
        var sql = """
            SELECT r.id
            FROM recipes r
            LEFT JOIN recipe_ingredients ri ON r.id = ri.recipe_id
            LEFT JOIN ingredients i ON ri.ingredient_id = i.id
            WHERE r.is_archived = 0
        """
        
        var parameters: [Any] = []
        
        if !query.isEmpty {
            sql += " AND r.title LIKE ?"
            parameters.append("%\(query)%")
        }
        
        if let ingredients = ingredients, !ingredients.isEmpty {
            let placeholders = Array(repeating: "?", count: ingredients.count).joined(separator: ",")
            sql += " AND r.id IN ("
            sql += "    SELECT recipe_id FROM recipe_ingredients ri2"
            sql += "    JOIN ingredients i2 ON ri2.ingredient_id = i2.id"
            sql += "    WHERE i2.name IN (\(placeholders))"
            sql += "    GROUP BY recipe_id"
            sql += "    HAVING COUNT(DISTINCT i2.name) = ?"
            sql += ")"
            
            parameters.append(contentsOf: ingredients)
            parameters.append(ingredients.count)
        }
        
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
        
        sql += " ORDER BY RANDOM() LIMIT 1"
        
        let resultMap: (SQLiteRow) -> Int = { row in
            return row[0] as? Int ?? 0
        }
        
        let ids = try runQuery(sql, parameters: parameters, mapRow: resultMap)
        return ids.first
    }
}
