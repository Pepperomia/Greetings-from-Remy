import SwiftUI

@main
struct Greetings_from_RemyApp: App {
    init() {
        DatabaseBootstrap.ensureDatabaseCopiedFromBundle()
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
