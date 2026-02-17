import Foundation

enum DatabaseBootstrap {
    static let dbFileName = "recipes_app_seed_v13.sqlite"

    static func appDatabaseURL() -> URL {
        let fm = FileManager.default
        let dir = try! fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let appDir = dir.appendingPathComponent("GreetingsFromRemy", isDirectory: true)
        try? fm.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent(dbFileName)
    }

    static func ensureDatabaseCopiedFromBundle() {
        let fm = FileManager.default
        let dstURL = appDatabaseURL()

        if fm.fileExists(atPath: dstURL.path) {
            print("✅ DB already exists:", dstURL.path)
            return
        }

        guard let srcURL = Bundle.main.url(forResource: "recipes_app_seed_v13", withExtension: "sqlite") else {
            print("❌ DB not found in Bundle. Проверь, что файл добавлен в App target.")
            return
        }

        do {
            try fm.copyItem(at: srcURL, to: dstURL)
            print("✅ DB copied to:", dstURL.path)
        } catch {
            print("❌ ERROR copying DB:", error)
        }
    }
}
