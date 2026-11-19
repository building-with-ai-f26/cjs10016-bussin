import XCTest
import CoreLocation
@testable import Bussin

/// Go mode, replayed. The route is a 4 km square loop with a stop at each corner:
/// s1 at 0 m, s2 at 1000 m, s3 at 2000 m, s4 at 3000 m, then back to s1.
/// The trip boards at s1 and gets off at s3, two stops later.
final class TripSessionTests: XCTestCase {
    private var g: RouteGeometry!
    private var stops: [String: ShuttleStop] = [:]
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        let lat0 = 40.73, lon0 = -74.0
        let dLat = 1000.0 / 111_132.0
        let dLon = 1000.0 / (111_320.0 * cos(lat0 * .pi / 180))
        let c = { (la: Double, lo: Double) in CLLocationCoordinate2D(latitude: la, longitude: lo) }
        let corners = [c(lat0, lon0), c(lat0 + dLat, lon0), c(lat0 + dLat, lon0 + dLon), c(lat0, lon0 + dLon)]
        let route = ShuttleRoute(id: "T", name: "Route T", letter: "T", colorHex: "#000000",
                                 coordinates: corners + [corners[0]], stopIds: ["s1", "s2", "s3", "s4", "s1"])
        for (i, corner) in corners.enumerated() {
            stops["s\(i + 1)"] = ShuttleStop(id: "s\(i + 1)", name: "Stop \(i + 1)", coordinate: corner, routeIds: ["T"])
        }
        g = try XCTUnwrap(RouteGeometry.build(route: route, stops: stops))
    }

    private func option(busId: Int = 1) -> TripPlanner.Option {
        TripPlanner.Option(routeId: "T", boardStopId: "s1", alightStopId: "s3", walkToStop: 120, busArrives: 200,
                           ride: 400, walkFromStop: 60, total: 660, stopCount: 2, isEstimate: false,
                           boardDistance: 0, rideMeters: 2000, busId: busId)
    }

    /// 100 m past the get-off stop, out along the next leg: the trip's destination.
    private var destination: CLLocationCoordinate2D { g.pointCoordinate(at: 2100) }

    private func session(busId: Int = 1) throws -> TripSession {
        try XCTUnwrap(TripSession(option: option(busId: busId), destination: destination,
                                  geometry: g, stops: stops, now: start))
    }

    private func bus(_ id: Int, at d: Double, speed: Double = 5) -> TrackedBus {
        let along = (d.truncatingRemainder(dividingBy: g.length) + g.length).truncatingRemainder(dividingBy: g.length)
        return TrackedBus(bus: LiveBus(id: id, number: "\(id)", routeId: "T", coordinate: g.pointCoordinate(at: along),
                                       headingDegrees: nil, ridersAboard: nil, capacity: nil, isStale: false),
                          distanceAlong: along, speed: speed)
    }

    /// A point `meters` due west of the route at distance `d` (off to the side, like a sidewalk).
    private func beside(_ d: Double, meters: Double) -> CLLocationCoordinate2D {
        let p = g.pointCoordinate(at: d)
        return CLLocationCoordinate2D(latitude: p.latitude,
                                      longitude: p.longitude - meters / (111_320.0 * cos(p.latitude * .pi / 180)))
    }

    private func at(_ seconds: Double) -> Date { start.addingTimeInterval(seconds) }

    func testTheRideKnowsEveryStopItPasses() throws {
        let s = try session()
        XCTAssertEqual(s.rideStops.map(\.stopId), ["s2", "s3"])
        XCTAssertEqual(s.stopsLeft, 2)
    }

    func testWalkingToTheStopCountsDownTheBus() throws {
        var s = try session()
        _ = s.update(me: beside(0, meters: 300), buses: [bus(1, at: 3000)], now: at(4))
        XCTAssertEqual(s.step, .toStop)
        XCTAssertEqual(s.busId, 1)
        XCTAssertEqual(try XCTUnwrap(s.busSecondsAway), 200, accuracy: 1, "1000 m away at 5 m/s")
    }

    func testStandingAtTheStopIsWaiting() throws {
        var s = try session()
        _ = s.update(me: beside(0, meters: 10), buses: [bus(1, at: 3500)], now: at(4))
        XCTAssertEqual(s.step, .atStop)
    }

    func testBoardingNeedsTheBusToPullAwayWithYouOnIt() throws {
        var s = try session()
        _ = s.update(me: beside(0, meters: 5), buses: [bus(1, at: 0)], now: at(4))
        XCTAssertEqual(s.step, .atStop, "a bus at the stop with you beside it: not aboard yet")
        _ = s.update(me: g.pointCoordinate(at: 60), buses: [bus(1, at: 60)], now: at(8))
        XCTAssertEqual(s.step, .riding)
        XCTAssertEqual(s.stopsLeft, 2)
        XCTAssertEqual(s.nextStopId, "s2")
    }

    func testTheGetOffAlertFiresOnceWhenTheBusPassesTheStopBeforeYours() throws {
        var s = try session()
        _ = s.update(me: beside(0, meters: 5), buses: [bus(1, at: 0)], now: at(4))
        _ = s.update(me: g.pointCoordinate(at: 60), buses: [bus(1, at: 60)], now: at(8))
        XCTAssertEqual(s.update(me: g.pointCoordinate(at: 900), buses: [bus(1, at: 900)], now: at(12)), [])
        XCTAssertEqual(s.update(me: g.pointCoordinate(at: 1050), buses: [bus(1, at: 1050)], now: at(16)), [.getOffNext])
        XCTAssertEqual(s.step, .getOffNext)
        XCTAssertEqual(s.stopsLeft, 1)
        XCTAssertEqual(s.update(me: g.pointCoordinate(at: 1300), buses: [bus(1, at: 1300)], now: at(20)), [],
                       "no second buzz")
    }

    func testGettingOffThenWalkingToTheDestinationEndsTheTrip() throws {
        var s = try session()
        _ = s.update(me: beside(0, meters: 5), buses: [bus(1, at: 0)], now: at(4))
        _ = s.update(me: g.pointCoordinate(at: 60), buses: [bus(1, at: 60)], now: at(8))
        _ = s.update(me: g.pointCoordinate(at: 1050), buses: [bus(1, at: 1050)], now: at(12))
        XCTAssertEqual(s.update(me: g.pointCoordinate(at: 1995), buses: [bus(1, at: 1995)], now: at(16)), [.gotOff])
        XCTAssertEqual(s.step, .toDestination)
        XCTAssertEqual(s.update(me: g.pointCoordinate(at: 2060), buses: [bus(1, at: 2400)], now: at(40)), [.arrived])
        XCTAssertEqual(s.step, .arrived)
        XCTAssertTrue(s.isOver)
    }

    func testMissingYourBusSwitchesToTheNextOne() throws {
        var s = try session()
        _ = s.update(me: beside(0, meters: 400), buses: [bus(1, at: 3900), bus(2, at: 1500)], now: at(4))
        XCTAssertEqual(s.busId, 1)
        // Bus 1 goes by while you're still 400 m away.
        let events = s.update(me: beside(0, meters: 350), buses: [bus(1, at: 80), bus(2, at: 1600)], now: at(8))
        XCTAssertEqual(events, [.switchedBus(from: 1, to: 2)])
        XCTAssertEqual(s.busId, 2)
        XCTAssertEqual(try XCTUnwrap(s.busSecondsAway), 480, accuracy: 1, "2400 m away at 5 m/s")
        XCTAssertEqual(s.step, .toStop)
    }

    func testStandingBesideABusYouDontBoardIsNotRiding() throws {
        var s = try session()
        _ = s.update(me: beside(0, meters: 5), buses: [bus(1, at: 0), bus(2, at: 2000)], now: at(4))
        _ = s.update(me: beside(0, meters: 5), buses: [bus(1, at: 5), bus(2, at: 2020)], now: at(8))
        let events = s.update(me: beside(0, meters: 5), buses: [bus(1, at: 150), bus(2, at: 2040)], now: at(12))
        XCTAssertNotEqual(s.step, .riding, "the bus left and you stayed at the stop")
        XCTAssertEqual(events, [.switchedBus(from: 1, to: 2)])
    }

    func testIfYourBusDropsOffTheFeedMidRideYourOwnLocationKeepsCount() throws {
        var s = try session()
        _ = s.update(me: beside(0, meters: 5), buses: [bus(1, at: 0)], now: at(4))
        _ = s.update(me: g.pointCoordinate(at: 60), buses: [bus(1, at: 60)], now: at(8))
        XCTAssertEqual(s.update(me: g.pointCoordinate(at: 1100), buses: [], now: at(12)), [.getOffNext])
        XCTAssertEqual(s.step, .getOffNext)
    }

    func testATripEndsByItselfAfterTwoHours() throws {
        var s = try session()
        XCTAssertEqual(s.update(me: beside(0, meters: 300), buses: [bus(1, at: 3000)], now: at(2 * 3600 + 1)),
                       [.timedOut])
        XCTAssertTrue(s.isOver)
    }
}
