import CoreText
import Foundation

/// Registers any .ttf/.otf bundled with the app (Bagel Fat One, Lexend) at launch.
enum FontRegistry {
    static func registerBundledFonts(bundle: Bundle = .main) {
        let urls = (bundle.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
            + (bundle.urls(forResourcesWithExtension: "otf", subdirectory: nil) ?? [])
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
