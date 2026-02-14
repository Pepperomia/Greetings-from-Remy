import SwiftUI

struct ContentView: View {
    var body: some View {
        RootView()
            .onAppear {
                do {
                    try DatabaseManager.shared.ensureInitialTaxonomy()
                } catch {
                    print("Taxonomy migration error:", error)
                }
            }
            .onAppear {
                do {
                    try DatabaseManager.shared.fixCategoryDuplicatesForUI()
                } catch {
                    print("fixCategoryDuplicatesForUI error:", error)
                }
            }
    }
}
