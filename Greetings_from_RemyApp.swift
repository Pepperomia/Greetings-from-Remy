import SwiftUI

@main
struct Greetings_from_RemyApp: App {
    // MARK: - Init
    
    init() {
        try? DatabaseBootstrap.removeDatabase()
        _ = DatabaseBootstrap.ensureDatabaseCopiedFromBundle()
        let copied = DatabaseBootstrap.ensureDatabaseCopiedFromBundle()
        print("📦 copied:", copied)

        DatabaseBootstrap.checkDatabaseStatus()
    }
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            MainContentView()
        }
    }
}
