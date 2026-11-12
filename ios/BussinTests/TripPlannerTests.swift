import XCTest
import CoreLocation
@testable import Bussin

final class TripPlannerTests: XCTestCase {
    private struct World {
        let catalog: ShuttleCatalog
        let gs: [String: RouteGeometry]
        let stops: [String: ShuttleStop]
        func route(_ letter: String) throws -> (ShuttleRoute, RouteGeometry) {
            let r = try XCTUnwrap(catalog.routes.first { $0.letter == letter })
            return (r, try XCTUnwrap(gs[r.id]))
        }
        func coord(_ stopId: String) throws -> CLLocationCoordinate2D { try XCTUnwrap(stops[stopId]).coordinate }
    }

    private func world() throws -> World {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "stops", withExtension: "json"))
        let payload = try JSONDecoder().decode(PassioStopsPayload.self, from: Data(contentsOf: url))
        let catalog = ShuttleCatalog.from(payload: payload)
        let stops = Dictionary(uniqueKeysWithValues: catalog.stops.map { ($0.id, $0) })
        let gs = Dictionary(uniqueKeysWithValues: catalog.routes.compactMap { r in
            RouteGeometry.build(route: r, stops: stops).map { (r.id, $0) }
        })
        return World(catalog: catalog, gs: gs, stops: stops)
    }

    private func bus(_ id: Int, _ route: String, at d: Double, g: RouteGeometry, speed: Double = 4) -> TrackedBus {
        let along = ((d.truncatingRemainder(dividingBy: g.length)) + g.length).truncatingRemainder(dividingBy: g.length)
        return TrackedBus(bus: LiveBus(id: id, number: "\(id)", routeId: route,
                                       coordinate: g.pointCoordinate(at: along), headingDegrees: nil,
                                       ridersAboard: nil, capacity: nil, isStale: false),
                          distanceAlong: along, speed: speed)
    }

    /// Board at stop 1 of Route A; get off at whichever later stop is farthest away as the crow flies.
    private func longRide(_ w: World) throws -> (route: ShuttleRoute, g: RouteGeometry,
                                                  board: (stopId: String, distance: Double),
                                                  alight: (stopId: String, distance: Double)) {
        let (a, g) = try w.route("A")
        let entries = Array(g.stopDistances.dropLast())
        let board = entries[1]
        let from = try w.coord(board.stopId)
        let alight = try XCTUnwrap(entries.dropFirst(2).max {
            Walk.meters(from, w.stops[$0.stopId]!.coordinate) < Walk.meters(from, w.stops[$1.stopId]!.coordinate)
        })
        return (a, g, board, alight)
    }

    func testWalkUsesDetourAndPace() {
        let a = CLLocationCoordinate2D(latitude: 40.73, longitude: -74.0)
        let b = CLLocationCoordinate2D(latitude: 40.73 + 1000.0 / 111_132.0, longitude: -74.0)   // 1 km north
        XCTAssertEqual(Walk.meters(a, b), 1250, accuracy: 1)
        XCTAssertEqual(Walk.seconds(a, b), 1250 / 1.3, accuracy: 1)
    }

    func testShuttleBeatsWalkingOnALongTrip() throws {
        let w = try world()
        let t = try longRide(w)
        let origin = try w.coord(t.board.stopId), dest = try w.coord(t.alight.stopId)
        let planner = TripPlanner(geometries: w.gs, stops: w.stops,
                                  buses: [bus(1, t.route.id, at: t.board.distance - 400, g: t.g)])   // 100 s away
        let plan = planner.plan(from: origin, to: dest)
        XCTAssertEqual(plan.verdict, .shuttle)
        let o = try XCTUnwrap(plan.options.first)
        XCTAssertEqual(o.routeId, t.route.id)
        let direct = 100 + (t.alight.distance - t.board.distance) / 4
        XCTAssertLessThanOrEqual(o.total, direct + 1, "never worse than the obvious ride")
        XCTAssertLessThan(o.total, plan.walkSeconds - 60)
        XCTAssertEqual(o.total, o.busArrives + o.ride + o.walkFromStop, accuracy: 0.01)
    }

    func testNeverPlansABusYouCannotReach() throws {
        let w = try world()
        let t = try longRide(w)
        let stop = try w.coord(t.board.stopId)
        // Stand ~250 walking metres (about 3 min) from the stop; the first bus is 100 s out.
        let origin = CLLocationCoordinate2D(latitude: stop.latitude + 200.0 / 111_132.0, longitude: stop.longitude)
        let planner = TripPlanner(geometries: w.gs, stops: w.stops, buses: [
            bus(1, t.route.id, at: t.board.distance - 400, g: t.g),
            bus(2, t.route.id, at: t.board.distance - 2400, g: t.g),
        ])
        let plan = planner.plan(from: origin, to: try w.coord(t.alight.stopId))
        XCTAssertFalse(plan.options.isEmpty)
        for o in plan.options {
            XCTAssertGreaterThanOrEqual(o.busArrives, o.walkToStop + TripPlanner.boardingBuffer)
        }
    }

    func testShortHopIsAWalk() throws {
        let w = try world()
        let (a, g) = try w.route("A")
        let s = try w.coord(g.stopDistances[1].stopId)
        let dest = CLLocationCoordinate2D(latitude: s.latitude + 150.0 / 111_132.0, longitude: s.longitude)
        let planner = TripPlanner(geometries: w.gs, stops: w.stops,
                                  buses: [bus(1, a.id, at: g.stopDistances[1].distance - 400, g: g)])
        let plan = planner.plan(from: s, to: dest)
        XCTAssertTrue(plan.options.isEmpty)
        XCTAssertEqual(plan.verdict, .walk)
    }

    func testLoopWrapsPastTheStart() throws {
        let w = try world()
        let (a, g) = try w.route("A")
        XCTAssertTrue(g.isLoop)
        let entries = Array(g.stopDistances.dropLast())
        let board = try XCTUnwrap(entries.last), alight = entries[0]
        let planner = TripPlanner(geometries: w.gs, stops: w.stops,
                                  buses: [bus(1, a.id, at: board.distance - 400, g: g)])
        let o = try XCTUnwrap(planner.bestOption(routeId: a.id,
                                                 from: try w.coord(board.stopId), to: try w.coord(alight.stopId)))
        XCTAssertLessThanOrEqual(o.total, 100 + (g.length - board.distance) / 4 + 1,
                                 "rides through the start of the loop instead of going all the way round")
    }

    func testFarAwayPlaceIsTooFar() throws {
        let w = try world()
        let t = try longRide(w)
        let jfk = CLLocationCoordinate2D(latitude: 40.6413, longitude: -73.7781)
        let planner = TripPlanner(geometries: w.gs, stops: w.stops,
                                  buses: [bus(1, t.route.id, at: t.board.distance - 400, g: t.g)])
        let plan = planner.plan(from: try w.coord(t.board.stopId), to: jfk)
        XCTAssertTrue(plan.options.isEmpty, "a 20-minute cap on the last walk rules every stop out")
        XCTAssertEqual(plan.verdict, .tooFar)
    }

    func testALongTripStillOffersASlowShuttle() throws {
        let w = try world()
        let t = try longRide(w)
        // You just missed the only bus and it is crawling, so the shuttle is slower than walking.
        // But the walk is over 45 minutes, and nobody wants to be told to walk that.
        let planner = TripPlanner(geometries: w.gs, stops: w.stops,
                                  buses: [bus(1, t.route.id, at: t.board.distance + 200, g: t.g, speed: 1.5)])
        let plan = planner.plan(from: try w.coord(t.board.stopId), to: try w.coord(t.alight.stopId))
        XCTAssertGreaterThan(plan.walkSeconds, TripPlanner.tooFarToWalk, "fixture check: this is a long walk")
        let o = try XCTUnwrap(plan.options.first)
        XCTAssertGreaterThan(o.total, plan.walkSeconds, "fixture check: the shuttle really is slower")
        XCTAssertEqual(plan.verdict, .shuttle)
    }

    func testNoBusesMeansNoOptionsAndNamesIdleRoutes() throws {
        let w = try world()
        let t = try longRide(w)
        let plan = TripPlanner(geometries: w.gs, stops: w.stops, buses: [])
            .plan(from: try w.coord(t.board.stopId), to: try w.coord(t.alight.stopId))
        XCTAssertTrue(plan.options.isEmpty)
        XCTAssertTrue(plan.idleRouteIds.contains(t.route.id), "Route A stops at the destination but has no buses out")
    }

    func testWithoutAppleTimesThePlanIsMarkedAnEstimate() throws {
        let w = try world()
        let t = try longRide(w)
        let planner = TripPlanner(geometries: w.gs, stops: w.stops,
                                  buses: [bus(1, t.route.id, at: t.board.distance - 400, g: t.g)])
        let plan = planner.plan(from: try w.coord(t.board.stopId), to: try w.coord(t.alight.stopId))
        XCTAssertTrue(plan.isEstimate)
    }

    func testARealWalkToTheStopCanMeanALaterBus() throws {
        let w = try world()
        let t = try longRide(w)
        let origin = try w.coord(t.board.stopId), dest = try w.coord(t.alight.stopId)
        let planner = TripPlanner(geometries: w.gs, stops: w.stops, buses: [
            bus(1, t.route.id, at: t.board.distance - 400, g: t.g),     // 100 s out
            bus(2, t.route.id, at: t.board.distance - 2400, g: t.g),    // 600 s out
        ])
        // Apple says the short hops to and from the stops take 5 minutes each; it hasn't answered the long walk yet.
        let apple: WalkLookup = { a, b in Walk.meters(a, b) < 100 ? WalkLeg(seconds: 300, meters: 390) : nil }
        let plan = planner.plan(from: origin, to: dest, walks: apple)
        let o = try XCTUnwrap(plan.options.first)
        XCTAssertEqual(o.walkToStop, 300)
        XCTAssertGreaterThanOrEqual(o.busArrives, 330, "the 100-second bus leaves before you get there")
        XCTAssertFalse(o.isEstimate)
        XCTAssertTrue(plan.isEstimate, "the whole-way walk is still a guess")
    }

    func testARealWalkThatBeatsTheShuttleDropsIt() throws {
        let w = try world()
        let t = try longRide(w)
        let planner = TripPlanner(geometries: w.gs, stops: w.stops,
                                  buses: [bus(1, t.route.id, at: t.board.distance - 400, g: t.g)])
        // Apple knows a shortcut: every walk, including the whole way, takes 5 minutes.
        let apple: WalkLookup = { _, _ in WalkLeg(seconds: 300, meters: 390) }
        let plan = planner.plan(from: try w.coord(t.board.stopId), to: try w.coord(t.alight.stopId), walks: apple)
        XCTAssertTrue(plan.options.isEmpty)
        XCTAssertEqual(plan.verdict, .walk)
        XCTAssertEqual(plan.walkSeconds, 300)
        XCTAssertEqual(plan.walkMeters, 390)
        XCTAssertFalse(plan.isEstimate)
    }
}
