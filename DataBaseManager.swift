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

        for (idx,param) in parameters.enumerated() {

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
        SELECT c.id,c.name,COUNT(r.id)
        FROM categories c
        LEFT JOIN recipes r
        ON r.category_id=c.id AND r.is_archived=0
        GROUP BY c.id,c.name
        ORDER BY c.sort_order,c.name
        """

        return try runQuery(sql) { row in

            CategoryRow(
                id: row[0] as? Int ?? 0,
                name: row[1] as? String ?? "",
                count: row[2] as? Int ?? 0
            )
        }
    }

    // MARK: ADD CATEGORY

    func addCategory(name: String) throws {

        let sql = "INSERT INTO categories(name) VALUES (?)"

        _ = try runQuery(sql, parameters: [name]) { _ in 0 }
    }

    // MARK: ADD CUISINE

    func addCuisine(name: String) throws {

        let sql = "INSERT INTO cuisines(name) VALUES (?)"

        _ = try runQuery(sql, parameters: [name]) { _ in 0 }
    }

    // MARK: RECIPES BY CATEGORY

    func fetchRecipes(categoryId: Int, maxMinutes: Int? = nil) throws -> [RecipeRow] {

        var sql = """
        SELECT id,title,time_minutes,difficulty
        FROM recipes
        WHERE category_id=? AND is_archived=0
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
                difficulty: row[3] as? String ?? "medium"
            )
        }
    }

    // MARK: SEARCH

    func searchRecipes(query: String) throws -> [RecipeRow] {

        let sql = """
        SELECT DISTINCT r.id,r.title,r.time_minutes,r.difficulty
        FROM recipes r
        LEFT JOIN recipe_ingredients ri ON ri.recipe_id=r.id
        LEFT JOIN ingredients i ON i.id=ri.ingredient_id
        WHERE r.is_archived=0
        AND (r.title LIKE ? OR i.name LIKE ?)
        ORDER BY r.title
        LIMIT 200
        """

        return try runQuery(
            sql,
            parameters: ["%\(query)%","%\(query)%"]
        ) { row in

            RecipeRow(
                id: row[0] as? Int ?? 0,
                title: row[1] as? String ?? "",
                timeMinutes: row[2] as? Int ?? 0,
                difficulty: row[3] as? String ?? "medium"
            )
        }
    }

    // MARK: RECIPE DETAIL

    func fetchRecipeDetail(recipeId: Int) throws -> RecipeDetail {

        let sql = """
        SELECT r.id,r.title,c.name,cu.name,r.difficulty,
               r.time_minutes,r.servings_text,r.instructions,
               r.calories,r.protein,r.fat,r.carbs
        FROM recipes r
        JOIN categories c ON c.id=r.category_id
        LEFT JOIN cuisines cu ON cu.id=r.cuisine_id
        WHERE r.id=? AND r.is_archived=0
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
        SELECT ri.id,i.name,ri.amount_text,ri.sort_order
        FROM recipe_ingredients ri
        JOIN ingredients i ON i.id=ri.ingredient_id
        WHERE ri.recipe_id=?
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
}

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
