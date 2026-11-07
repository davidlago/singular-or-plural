import SwiftUI
import SwiftData

@main
struct OneOrManyApp: App {
    init() {
        FontRegistry.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: AppSchema.models)
    }
}
