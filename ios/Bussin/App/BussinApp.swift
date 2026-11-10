import SwiftUI

@main
struct BussinApp: App {
    init() { Analytics.start() }
    var body: some Scene {
        WindowGroup {
            MapScreen()
        }
    }
}
