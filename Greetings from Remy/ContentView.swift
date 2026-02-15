import SwiftUI

struct ContentView: View {
    @State private var didBootstrap = false

    var body: some View {
        RootView()
            .onAppear {
                guard !didBootstrap else { return }
                didBootstrap = true

                do {
                    try DatabaseManager.shared.ensureInitialTaxonomy()
                } catch {
                    print("Taxonomy migration error:", error)
                }

                // Важно: это часто вызывает “дублирование” при повторных onAppear.
                // Оставь выключенным, пока UI стабилизируем.
                // do {
                //     try DatabaseManager.shared.fixCategoryDuplicatesForUI()
                // } catch {
                //     print("fixCategoryDuplicatesForUI error:", error)
                // }
            }
    }
}
