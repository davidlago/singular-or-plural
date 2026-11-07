import SwiftData
import SwiftUI

@main
struct OneOrManyApp: App {
    init() {
        FontRegistry.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let scene = ScreenshotMode.scene {
                ScreenshotRoot(scene: scene).modelContainer(ScreenshotMode.container)
            } else {
                RootView().modelContainer(for: AppSchema.models)
            }
            #else
            RootView().modelContainer(for: AppSchema.models)
            #endif
        }
    }
}
