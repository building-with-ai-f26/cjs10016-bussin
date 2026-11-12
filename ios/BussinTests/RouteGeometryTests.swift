import XCTest
import CoreLocation
@testable import Bussin

final class RouteGeometryTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    /// A 1 km × 1 km square loop starting at (40.73, -74.0), run clockwise.
    private func squareRoute() -> ShuttleRoute {
        let lat0 = 40.73, lon0 = -74.0
        let dLat = 1000.0 / 111_132.0
        let dLon = 1000.0 / (111_320.0 * cos(lat0 * .pi / 180))
        let c = { (la: Double, lo: Double) in CLLocationCoordinate2D(latitude: la, longitude: lo) }
        return ShuttleRoute(id: "T", name: "Test", letter: "A", colorHex: "#000000",
                            coordinates: [c(lat0, lon0), c(lat0 + dLat, lon0), c(lat0 + dLat, lon0 + dLon),
                                          c(lat0, lon0 + dLon), c(lat0, lon0)],
                            stopIds: ["s1", "s2", "s1"])
    }

    func testSquareLoopBasics() throws {
        let r = squareRoute()
        let stops = [
            "s1": ShuttleStop(id: "s1", name: "Start", coordinate: r.coordinates[0], routeIds: ["T"]),
            "s2": ShuttleStop(id: "s2", name: "Half", coordinate: r.coordinates[2], routeIds: ["T"]),
        ]
        let g = try XCTUnwrap(RouteGeometry.build(route: r, stops: stops))
        XCTAssertEqual(g.length, 4000, accuracy: 20)
        XCTAssertTrue(g.isLoop)
        XCTAssertEqual(g.stopDistances.count, 3)
        XCTAssertEqual(g.stopDistances[0].distance, 0, accuracy: 10)
        XCTAssertEqual(g.stopDistances[1].distance, 2000, accuracy: 20)
        XCTAssertEqual(g.stopDistances[2].distance, g.length, accuracy: 1)  // loop closes at its first stop

        // A point 10 m east of the first leg, 500 m up it:
        let p = CLLocationCoordinate2D(latitude: 40.73 + 500.0 / 111_132.0,
                                       longitude: -74.0 + 10.0 / (111_320.0 * cos(40.73 * .pi / 180)))
        let proj = g.project(p)
        XCTAssertEqual(proj.distanceAlong, 500, accuracy: 15)
        XCTAssertEqual(proj.offsetMeters, 10, accuracy: 5)
    }

    func testRealRoutesBuildAndOrderStops() throws {
        let payload = try JSONDecoder().decode(PassioStopsPayload.self, from: fixture("stops"))
        let catalog = ShuttleCatalog.from(payload: payload)
        let stopsById = Dictionary(uniqueKeysWithValues: catalog.stops.map { ($0.id, $0) })
        for route in catalog.routes {
            let g = try XCTUnwrap(RouteGeometry.build(route: route, stops: stopsById), route.name)
            XCTAssertGreaterThan(g.length, 2000, "\(route.name) should be km-scale")
            XCTAssertLessThan(g.length, 40_000, route.name)
            // Boarding order must be monotonically increasing along the line.
            let ds = g.stopDistances.map(\.distance)
            XCTAssertEqual(ds, ds.sorted(), "\(route.name) stop order got scrambled")
            // Every stop sits near its route (the feed's own stops, so < 150 m).
            for sd in g.stopDistances {
                guard let st = stopsById[sd.stopId] else { continue }
                XCTAssertLessThan(g.project(st.coordinate).offsetMeters, 150,
                                  "\(st.name) far from \(route.name)")
            }
        }
    }

    func testOffCorridorDetection() throws {
        let payload = try JSONDecoder().decode(PassioStopsPayload.self, from: fixture("stops"))
        let catalog = ShuttleCatalog.from(payload: payload)
        let stopsById = Dictionary(uniqueKeysWithValues: catalog.stops.map { ($0.id, $0) })
        let b = try XCTUnwrap(catalog.routes.first { $0.letter == "B" })
        let g = try XCTUnwrap(RouteGeometry.build(route: b, stops: stopsById))
        // The real glitch we logged on Nov 10: a Route B bus reporting New Hampshire.
        let nh = CLLocationCoordinate2D(latitude: 43.4824178, longitude: -71.5483933)
        XCTAssertGreaterThan(g.project(nh).offsetMeters, 300)
    }
}
