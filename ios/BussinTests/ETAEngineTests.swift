import XCTest
import CoreLocation
@testable import Bussin

final class ETAEngineTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    private func world() throws -> (catalog: ShuttleCatalog, gs: [String: RouteGeometry]) {
        let payload = try JSONDecoder().decode(PassioStopsPayload.self, from: fixture("stops"))
        let catalog = ShuttleCatalog.from(payload: payload)
        let stopsById = Dictionary(uniqueKeysWithValues: catalog.stops.map { ($0.id, $0) })
        let gs = Dictionary(uniqueKeysWithValues: catalog.routes.compactMap { r in
            RouteGeometry.build(route: r, stops: stopsById).map { (r.id, $0) }
        })
        return (catalog, gs)
    }

    private func bus(_ id: Int, _ route: String, at d: Double, g: RouteGeometry, speed: Double = 4) -> TrackedBus {
        TrackedBus(bus: LiveBus(id: id, number: "\(id)", routeId: route,
                                coordinate: g.pointCoordinate(at: d), headingDegrees: nil,
                                ridersAboard: nil, capacity: nil, isStale: false),
                   distanceAlong: d, speed: speed)
    }

    func testArrivalIsDistanceOverSpeed() throws {
        let (catalog, gs) = try world()
        let a = try XCTUnwrap(catalog.routes.first { $0.letter == "A" })
        let g = try XCTUnwrap(gs[a.id])
        let stop = g.stopDistances[2]       // a mid-route stop
        let b = bus(1, a.id, at: stop.distance - 480, g: g, speed: 4)   // 480 m short of it
        let engine = ETAEngine(geometries: gs, buses: [b])
        let eta = try XCTUnwrap(engine.arrivals(routeId: a.id, stopId: stop.stopId, count: 1).first)
        XCTAssertEqual(eta, 120, accuracy: 10)   // 480 m / 4 m/s
    }

    func testEveryBusDueInTheNextHourWithItsNumber() throws {
        let (catalog, gs) = try world()
        let a = try XCTUnwrap(catalog.routes.first { $0.letter == "A" })
        let g = try XCTUnwrap(gs[a.id])
        let stop = g.stopDistances[2]
        // Bus 1 is 480 m short (2 min); bus 2 is 4800 m short (20 min). A lap at 4 m/s is about 54 min.
        let engine = ETAEngine(geometries: gs, buses: [bus(1, a.id, at: stop.distance - 480, g: g),
                                                       bus(2, a.id, at: stop.distance - 4800, g: g)])
        let lap = g.length / 4
        let list = engine.upcoming(routeId: a.id, stopId: stop.stopId, within: 3600)
        XCTAssertEqual(list.map(\.busId), lap + 120 <= 3600 ? [1, 2, 1] : [1, 2])
        XCTAssertEqual(list[0].seconds, 120, accuracy: 10)
        XCTAssertEqual(list[1].seconds, 1200, accuracy: 10)
        XCTAssertTrue(list.allSatisfy { $0.seconds <= 3600 }, "nothing past the hour")
        XCTAssertEqual(list.map(\.lap), lap + 120 <= 3600 ? [0, 0, 1] : [0, 0], "a bus's next time round is marked")
        XCTAssertTrue(engine.upcoming(routeId: a.id, stopId: stop.stopId, within: 60).isEmpty)
    }

    func testBusJustPastTheStopWrapsAround() throws {
        let (catalog, gs) = try world()
        let a = try XCTUnwrap(catalog.routes.first { $0.letter == "A" })  // A is a loop
        let g = try XCTUnwrap(gs[a.id])
        let stop = g.stopDistances[1]
        let b = bus(1, a.id, at: stop.distance + 100, g: g, speed: 4)    // 100 m past it
        let engine = ETAEngine(geometries: gs, buses: [b])
        let eta = try XCTUnwrap(engine.arrivals(routeId: a.id, stopId: stop.stopId, count: 1).first)
        XCTAssertEqual(eta, (g.length - 100) / 4, accuracy: 30, "has to go all the way around")
    }

    func testDeparturesSortSoonestFirst() throws {
        let (catalog, gs) = try world()
        let a = try XCTUnwrap(catalog.routes.first { $0.letter == "A" })
        let e = try XCTUnwrap(catalog.routes.first { $0.letter == "E" })
        let hub = "6545"   // 715 Broadway serves both
        let gA = try XCTUnwrap(gs[a.id]), gE = try XCTUnwrap(gs[e.id])
        let dA = try XCTUnwrap(gA.stopDistances.first { $0.stopId == hub }).distance
        let dE = try XCTUnwrap(gE.stopDistances.first { $0.stopId == hub }).distance
        let engine = ETAEngine(geometries: gs, buses: [
            bus(1, a.id, at: dA - 2000 < 0 ? dA - 2000 + gA.length : dA - 2000, g: gA),   // A: ~500 s away
            bus(2, e.id, at: dE - 400 < 0 ? dE - 400 + gE.length : dE - 400, g: gE),      // E: ~100 s away
        ])
        let deps = engine.departures(stopId: hub, routeIds: [a.id, e.id])
        XCTAssertEqual(deps.map(\.routeId), [e.id, a.id], "soonest route first")
        XCTAssertEqual(try XCTUnwrap(deps.first?.next), 100, accuracy: 15)
    }

    func testUpcomingStopsStartWithNearestAhead() throws {
        let (catalog, gs) = try world()
        let a = try XCTUnwrap(catalog.routes.first { $0.letter == "A" })
        let g = try XCTUnwrap(gs[a.id])
        // halfway between stop 1 and stop 2
        let mid = (g.stopDistances[1].distance + g.stopDistances[2].distance) / 2
        let b = bus(1, a.id, at: mid, g: g)
        let engine = ETAEngine(geometries: gs, buses: [b])
        let up = engine.upcomingStops(busId: 1)
        XCTAssertEqual(up.first?.stopId, g.stopDistances[2].stopId)
        // ETAs strictly increase around the loop, and the list visits every distinct stop once.
        XCTAssertEqual(up.map(\.secondsAway), up.map(\.secondsAway).sorted())
        let distinct = Set(g.stopDistances.dropLast().map(\.stopId))
        XCTAssertEqual(up.count, distinct.count)
    }
}
