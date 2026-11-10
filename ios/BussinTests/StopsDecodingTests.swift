import XCTest
@testable import Bussin

final class StopsDecodingTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    func testCatalogFromRealFeedSnapshot() throws {
        let payload = try JSONDecoder().decode(PassioStopsPayload.self, from: fixture("stops"))
        let catalog = ShuttleCatalog.from(payload: payload)

        // All seven lettered routes, nothing else (no Langone commuters, no ferries).
        XCTAssertEqual(Set(catalog.routes.map(\.letter)), ["A", "B", "C", "E", "F", "G", "W"])

        let a = try XCTUnwrap(catalog.routes.first { $0.letter == "A" })
        XCTAssertEqual(a.id, "74769")
        XCTAssertEqual(a.name, "Route A")
        XCTAssertGreaterThan(a.coordinates.count, 100)      // real polyline, flattened segments
        XCTAssertEqual(a.stopIds.count, 8)                  // includes the loop-closing repeat
        XCTAssertEqual(a.stopIds.first, a.stopIds.last)     // A is a loop

        // Coordinates are in Manhattan/Brooklyn, i.e. parsing didn't scramble lat/lng.
        for c in a.coordinates {
            XCTAssertTrue((40.5...40.9).contains(c.latitude), "bad lat \(c.latitude)")
            XCTAssertTrue((-74.2 ... -73.8).contains(c.longitude), "bad lng \(c.longitude)")
        }

        // The hub stop exists, consolidated across routes.
        let hub = try XCTUnwrap(catalog.stops.first { $0.id == "6545" })
        XCTAssertEqual(hub.name, "715 Broadway")
        XCTAssertGreaterThan(hub.routeIds.count, 1)

        // The feed's own suspension list survives. This snapshot was captured on a
        // Saturday (Nov 8, 2026): weekday routes are suspended, weekend route W runs.
        XCTAssertTrue(catalog.excludedRouteIds.contains("74770"), "B suspended on weekends")
        XCTAssertTrue(catalog.excludedRouteIds.contains("74768"), "E suspended on weekends")
        XCTAssertFalse(catalog.excludedRouteIds.contains("74774"), "W runs on weekends")
    }
}
