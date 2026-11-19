import XCTest
import CoreLocation
@testable import Bussin

/// Bus arrows. Passio's own "course" was within 30° of the road only 2 times in 14 on Nov 19,
/// so the arrow comes from the route instead, and where a route runs both ways along one street,
/// from which way the bus actually moved.
final class BusDirectionTests: XCTestCase {
    private let lat0 = 40.73, lon0 = -74.0
    private var mLon: Double { 111_320.0 * cos(lat0 * .pi / 180) }

    /// `north` and `east` in meters from (lat0, lon0).
    private func at(_ north: Double, _ east: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat0 + north / 111_132.0, longitude: lon0 + east / mLon)
    }

    private func geometry(_ corners: [(Double, Double)], id: String = "T") throws -> RouteGeometry {
        let coords = corners.map { at($0.0, $0.1) }
        let s1 = ShuttleStop(id: "s1", name: "Start", coordinate: coords[0], routeIds: [id])
        let route = ShuttleRoute(id: id, name: "Route T", letter: "T", colorHex: "#000000",
                                 coordinates: coords, stopIds: ["s1", "s1"])
        return try XCTUnwrap(RouteGeometry.build(route: route, stops: ["s1": s1]))
    }

    /// 1 km square, run clockwise: north, east, south, west.
    private func square() throws -> RouteGeometry {
        try geometry([(0, 0), (1000, 0), (1000, 1000), (0, 1000), (0, 0)])
    }

    /// Up a street 1 km and back down it, 10 m to the east (the other side of the road).
    private func outAndBack() throws -> RouteGeometry {
        try geometry([(0, 0), (1000, 0), (1000, 10), (0, 10), (0, 0)])
    }

    private func bus(_ id: Int, _ c: CLLocationCoordinate2D) -> LiveBus {
        LiveBus(id: id, number: "\(id)", routeId: "T", coordinate: c, headingDegrees: 200,
                ridersAboard: nil, capacity: nil, isStale: false)
    }

    private func angleGap(_ a: Double, _ b: Double) -> Double { abs((a - b + 540).truncatingRemainder(dividingBy: 360) - 180) }

    func testTheRouteKnowsWhichWayItRunsAtEveryPoint() throws {
        let g = try square()
        XCTAssertLessThan(angleGap(g.direction(at: 500), 0), 2, "first leg runs north")
        XCTAssertLessThan(angleGap(g.direction(at: 1500), 90), 2, "then east")
        XCTAssertLessThan(angleGap(g.direction(at: 2500), 180), 2, "then south")
        XCTAssertLessThan(angleGap(g.direction(at: 3500), 270), 2, "then west")
    }

    func testOnAStreetTheRouteUsesOnceTheArrowFollowsTheRouteNotPassio() throws {
        let g = try square()
        var tracker = BusTracker()
        let t = tracker.update(buses: [bus(1, at(500, 5))], geometries: ["T": g], at: Date(timeIntervalSince1970: 0))
        let heading = try XCTUnwrap(t.first?.heading, "one way only here, so it's known straight away")
        XCTAssertLessThan(angleGap(heading, 0), 2, "north, not Passio's 200°")
    }

    func testWhereTheRouteRunsBothWaysTheBusIsPlacedByHowItMoves() throws {
        let g = try outAndBack()
        let gs = ["T": g]
        let t0 = Date(timeIntervalSince1970: 0)

        var north = BusTracker()
        let first = north.update(buses: [bus(1, at(500, 5))], geometries: gs, at: t0)
        XCTAssertNil(first.first?.heading, "halfway between both sides and hasn't moved: no guess")
        let moved = try XCTUnwrap(north.update(buses: [bus(1, at(540, 5))], geometries: gs, at: t0 + 4).first)
        XCTAssertLessThan(angleGap(try XCTUnwrap(moved.heading), 0), 5, "moving north: the way up")
        XCTAssertEqual(moved.distanceAlong, 540, accuracy: 15)

        var south = BusTracker()
        _ = south.update(buses: [bus(2, at(500, 5))], geometries: gs, at: t0)
        let down = try XCTUnwrap(south.update(buses: [bus(2, at(460, 5))], geometries: gs, at: t0 + 4).first)
        XCTAssertLessThan(angleGap(try XCTUnwrap(down.heading), 180), 5, "moving south: the way back")
        XCTAssertEqual(down.distanceAlong, 1000 + 10 + 540, accuracy: 15, "and its arrival times count from there")
    }

    func testAParkedBusKeepsTheWayItWasGoing() throws {
        let g = try outAndBack()
        let gs = ["T": g]
        let t0 = Date(timeIntervalSince1970: 0)
        var tracker = BusTracker()
        _ = tracker.update(buses: [bus(1, at(500, 5))], geometries: gs, at: t0)
        _ = tracker.update(buses: [bus(1, at(460, 5))], geometries: gs, at: t0 + 4)
        let parked = try XCTUnwrap(tracker.update(buses: [bus(1, at(461, 5))], geometries: gs, at: t0 + 8).first)
        XCTAssertLessThan(angleGap(try XCTUnwrap(parked.heading), 180), 5, "a few meters of GPS drift doesn't flip it")
        XCTAssertEqual(parked.distanceAlong, 1000 + 10 + 539, accuracy: 15)
    }
}
