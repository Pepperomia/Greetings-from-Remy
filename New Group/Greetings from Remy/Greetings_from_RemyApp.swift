import SwiftUI

@main
struct Greetings_from_RemyApp: App {

    // MARK: - Init

    init() {

        print("🚀 App starting")

        try? DatabaseBootstrap.removeDatabase()

        let copied = DatabaseBootstrap.ensureDatabaseCopiedFromBundle()
        print("📦 database copied:", copied)

        DatabaseBootstrap.checkDatabaseStatus()

        DatabaseManager.shared.warmup()
    }
    

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            MainContentView()
        }
    }
}
