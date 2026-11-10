import XCTest
@testable import Bussin

final class BusesDecodingTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    func testLiveBusesFromRealCapture() throws {
        let payload = try JSONDecoder().decode(PassioBusesPayload.self, from: fixture("buses"))
        let lettered: Set<String> = ["74768", "74769", "74770", "74771", "74772", "74773", "74774"]
        let buses = LiveBus.from(payload: payload, allowedRouteIds: lettered)

        XCTAssertFalse(buses.isEmpty, "capture should hold at least one lettered-route bus")
        for bus in buses {
            XCTAssertTrue(lettered.contains(bus.routeId))
            XCTAssertTrue((40.5...40.9).contains(bus.coordinate.latitude))
            XCTAssertTrue((-74.2 ... -73.8).contains(bus.coordinate.longitude))
            XCTAssertFalse(bus.number.isEmpty)
        }
        // The feed's ridership fields survive the mapping on at least one bus.
        XCTAssertTrue(buses.contains { $0.ridersAboard != nil && $0.capacity != nil })
    }

    func testEmptyFeedDecodesToNoBuses() throws {
        // Overnight the PHP backend emits [] where the dict usually is.
        let data = Data(#"{"buses":[],"time":null}"#.utf8)
        let payload = try JSONDecoder().decode(PassioBusesPayload.self, from: data)
        XCTAssertTrue(LiveBus.from(payload: payload, allowedRouteIds: ["74769"]).isEmpty)
    }
}
