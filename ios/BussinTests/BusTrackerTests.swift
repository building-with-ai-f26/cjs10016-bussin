import XCTest
import CoreLocation
@testable import Bussin

final class BusTrackerTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    private func geometries() throws -> [String: RouteGeometry] {
        let payload = try JSONDecoder().decode(PassioStopsPayload.self, from: fixture("stops"))
        let catalog = ShuttleCatalog.from(payload: payload)
        let stopsById = Dictionary(uniqueKeysWithValues: catalog.stops.map { ($0.id, $0) })
        return Dictionary(uniqueKeysWithValues: catalog.routes.compactMap { r in
            RouteGeometry.build(route: r, stops: stopsById).map { (r.id, $0) }
        })
    }

    private func mkBus(_ id: Int, _ route: String, at c: CLLocationCoordinate2D) -> LiveBus {
        LiveBus(id: id, number: "\(id)", routeId: route, coordinate: c,
                headingDegrees: nil, ridersAboard: nil, capacity: nil, isStale: false)
    }

    func testDefaultSpeedAndDistance() throws {
        let gs = try geometries()
        let g = try XCTUnwrap(gs["74769"])
        var tracker = BusTracker()
        let tracked = tracker.update(buses: [mkBus(1, "74769", at: g.pointCoordinate(at: 0))],
                                     geometries: gs, at: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(tracked.count, 1)
        XCTAssertEqual(tracked[0].speed, 4.0, accuracy: 0.001, "no history yet — default speed")
        XCTAssertEqual(tracked[0].distanceAlong, 0, accuracy: 30)
    }

    func testSpeedLearnsFromMovement() throws {
        let gs = try geometries()
        let g = try XCTUnwrap(gs["74769"])
        var tracker = BusTracker()
        _ = tracker.update(buses: [mkBus(7, "74769", at: g.pointCoordinate(at: 0))],
                           geometries: gs, at: Date(timeIntervalSince1970: 0))
        let t2 = tracker.update(buses: [mkBus(7, "74769", at: g.pointCoordinate(at: 120))],
                                geometries: gs, at: Date(timeIntervalSince1970: 20))
        // moved 120 m in 20 s = 6 m/s, so the estimate nudges up from 4 — but gently
        XCTAssertGreaterThan(t2[0].speed, 4.1)
        XCTAssertLessThan(t2[0].speed, 4.6)
    }

    /// Bug seen live Nov 11: a bus paused at a red light for one 4-second poll and every
    /// downstream ETA jumped ~40% (22 → 31 min). One stopped ping must barely move the estimate.
    func testRedLightDoesNotWreckTheEstimate() throws {
        let gs = try geometries()
        let g = try XCTUnwrap(gs["74769"])
        var tracker = BusTracker()
        let here = g.pointCoordinate(at: 500)
        _ = tracker.update(buses: [mkBus(3, "74769", at: here)], geometries: gs, at: Date(timeIntervalSince1970: 0))
        let stopped = tracker.update(buses: [mkBus(3, "74769", at: here)], geometries: gs, at: Date(timeIntervalSince1970: 4))
        XCTAssertGreaterThan(stopped[0].speed, 3.8, "one paused poll should cost seconds, not minutes")
    }

    /// A bus that's truly crawling for minutes should still be believed.
    func testSustainedSlowdownIsLearned() throws {
        let gs = try geometries()
        let g = try XCTUnwrap(gs["74769"])
        var tracker = BusTracker()
        var t = 0.0, d = 0.0
        var last: [TrackedBus] = []
        for _ in 0..<60 {                                    // 4 minutes at 1.5 m/s
            last = tracker.update(buses: [mkBus(4, "74769", at: g.pointCoordinate(at: d))],
                                  geometries: gs, at: Date(timeIntervalSince1970: t))
            t += 4; d += 6
        }
        XCTAssertLessThan(last[0].speed, 2.6, "four minutes of crawling should lower the estimate")
    }

    func testOffCorridorBusIsDropped() throws {
        let gs = try geometries()
        var tracker = BusTracker()
        let nh = mkBus(9, "74770", at: CLLocationCoordinate2D(latitude: 43.4824178, longitude: -71.5483933))
        let tracked = tracker.update(buses: [nh], geometries: gs, at: .now)
        XCTAssertTrue(tracked.isEmpty, "a bus 300+ m off its route is a GPS glitch, not a bus")
    }
}
