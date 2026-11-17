import XCTest
@testable import Bussin

final class AnalyticsTests: XCTestCase {
    func testTestRunsAreLabelledDebugSoTheyCanBeFilteredOut() {
        // Unit tests build the Debug configuration. A TestFlight build is Release and says "release".
        XCTAssertEqual(Analytics.buildLabel, "debug")
    }
}
