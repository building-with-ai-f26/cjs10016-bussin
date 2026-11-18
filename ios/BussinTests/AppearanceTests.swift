import XCTest
import SwiftUI
@testable import Bussin

final class AppearanceTests: XCTestCase {
    func testTheAppOpensDarkUntilTheRiderPicksLight() {
        XCTAssertEqual(Appearance.standard, .dark)
        XCTAssertEqual(Appearance.standard.colorScheme, .dark)
        XCTAssertEqual(Appearance.light.colorScheme, .light)
    }

    func testTheChoiceIsStoredUnderAStableName() {
        // Changing these would silently reset every rider's choice.
        XCTAssertEqual(Appearance.storageKey, "appearance")
        XCTAssertEqual(Appearance(rawValue: "light"), .light)
        XCTAssertEqual(Appearance(rawValue: "dark"), .dark)
    }
}
