import SwiftUI

@main
struct BussinApp: App {
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.standard

    init() { Analytics.start() }
    var body: some Scene {
        WindowGroup {
            MapScreen()
                .preferredColorScheme(appearance.colorScheme)
        }
    }
}
