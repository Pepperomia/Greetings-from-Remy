import SwiftUI

@main
struct Greetings_from_RemyApp: App {
    // MARK: - Init
    
    init() {
        // Копируем базу данных при запуске приложения
        DatabaseBootstrap.ensureDatabaseCopiedFromBundle()
        // Проверяем статус (опционально, для отладки)
        DatabaseBootstrap.checkDatabaseStatus()
    }
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            MainContentView()
        }
    }
}
