import SwiftUI

/// Bussin opens in dark mode. Riders can switch to light at the bottom of Home,
/// and the choice is saved on the phone.
enum Appearance: String, CaseIterable, Identifiable {
    case dark, light

    static let storageKey = "appearance"
    static let standard: Appearance = .dark

    var id: String { rawValue }
    var title: String { self == .dark ? "Dark" : "Light" }
    var colorScheme: ColorScheme { self == .dark ? .dark : .light }
}
