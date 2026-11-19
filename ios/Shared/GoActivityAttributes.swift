import ActivityKit
import Foundation

/// What the lock screen card and the Dynamic Island show during a Go trip. Shared by the app,
/// which starts and updates the card, and the widget extension, which draws it.
struct GoActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String           // "4 stops left"
        var detail: String          // "Get off at 6 MetroTech Center · about 12 min"
        var leg: Int                // 0 walk to the stop, 1 ride, 2 walk after, 3 finished
        var minutes: Int?           // bus arriving (before boarding) or ride left (aboard)
        var stopsLeft: Int?         // while aboard
        var getOffNext: Bool
    }

    var routeLetter: String
    var routeColorHex: String
    var destinationName: String
}
