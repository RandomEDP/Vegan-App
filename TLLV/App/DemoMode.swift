import Foundation

/// Demo mode for screen recordings and App Store screenshots.
/// Launch with `-TLLVDemoMode` (Debug builds only) to preview the app as a
/// Premium member with a few saved places, without signing in.
enum DemoMode {
    static var isEnabled: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-TLLVDemoMode")
        #else
        return false
        #endif
    }

    /// Facing Heaven, Chippie, LD's Kitchen, Café Petiole, Chickenish.
    static let favouriteIDs = [14974, 1792020046025, 15689, 900013, 17508]
    static let dateNightIDs = [14974, 12755, 17168]
}
