# Bussin iOS Phase 2 — ETAs and Screens Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Real arrival times computed from live bus positions, and the app's screens: a bottom sheet over the map with Home (nearest stop + departures), Stop, Route, and Bus detail views — matching the HTML prototype and DESIGN.md.

**Architecture:** A pure-Swift geometry layer (`RouteGeometry`) snaps buses onto route polylines and measures distance along them; `ETAEngine` turns those distances into arrival times; `ShuttleStore` tracks per-bus speed and drops off-corridor GPS glitches. SwiftUI sheet with three detents hosts a NavigationStack of screens. All math is TDD'd against synthetic shapes and the real feed fixtures.

**Tech Stack:** Swift, SwiftUI, MapKit, XCTest. No new dependencies.

**Conventions (same as phase 1):** work on branch `ios-phase-2`; after any file add/remove run `cd ios && xcodegen generate`; build/test with `xcodebuild … -destination 'platform=iOS Simulator,name=iPhone 17'`; `git add` only named files; follow DESIGN.md ("Glance and Go": blue=interaction, green=live, red=alert; answer is biggest; system text styles and materials).

---

### Task 1: Route geometry — snap anything onto a route line

**Files:**
- Create: `ios/Bussin/Models/RouteGeometry.swift`, `ios/BussinTests/RouteGeometryTests.swift`

- [ ] **Step 1: Failing tests**

`ios/BussinTests/RouteGeometryTests.swift`:

```swift
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

        // A point 10 m east of the square's NW corner path, 500 m up the first leg:
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
```

- [ ] **Step 2: Run to verify compile failure** (`RouteGeometry` unknown):
`cd ios && xcodegen generate && cd .. && xcodebuild test -project ios/Bussin.xcodeproj -scheme Bussin -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:" | head -4`

- [ ] **Step 3: Implement `ios/Bussin/Models/RouteGeometry.swift`**

```swift
import Foundation
import CoreLocation

/// Everything the ETA math needs to know about one route's shape, in meters.
/// Coordinates are projected onto a flat local plane (fine below ~10 km spans).
struct RouteGeometry {
    let routeId: String
    let points: [SIMD2<Double>]     // meters, local plane
    let cumulative: [Double]        // running distance at each point
    let length: Double
    let isLoop: Bool
    /// Stops in boarding order with their distance along the line.
    /// A loop repeats the first stop at the end with distance == length.
    let stopDistances: [(stopId: String, distance: Double)]

    private let originLat: Double
    private let originLon: Double
    private let mPerDegLat = 111_132.0
    private let mPerDegLon: Double

    struct Projection {
        let distanceAlong: Double   // meters from the route's start
        let offsetMeters: Double    // perpendicular distance off the line
    }

    static func build(route: ShuttleRoute, stops: [String: ShuttleStop]) -> RouteGeometry? {
        guard route.coordinates.count >= 2 else { return nil }
        let o = route.coordinates[0]
        let mLon = 111_320.0 * cos(o.latitude * .pi / 180)
        func plane(_ c: CLLocationCoordinate2D) -> SIMD2<Double> {
            SIMD2((c.longitude - o.longitude) * mLon, (c.latitude - o.latitude) * 111_132.0)
        }
        let pts = route.coordinates.map(plane)
        var cum = [0.0]
        for i in 1..<pts.count { cum.append(cum[i - 1] + simd_distance(pts[i - 1], pts[i])) }
        let length = cum[cum.count - 1]
        guard length > 0 else { return nil }
        let isLoop = route.stopIds.count >= 2 && route.stopIds.first == route.stopIds.last

        var g = RouteGeometry(routeId: route.id, points: pts, cumulative: cum, length: length,
                              isLoop: isLoop, stopDistances: [],
                              originLat: o.latitude, originLon: o.longitude, mPerDegLon: mLon)

        // Assign each stop a distance along the line, in boarding order. Same scoring
        // as the prototype's build script: prefer the nearest segment, lightly penalize
        // jumping far ahead, and never go backwards past the previous stop.
        var assigned: [(String, Double)] = []
        var prev = -1.0
        let ids = route.stopIds
        for (k, sid) in ids.enumerated() {
            guard let stop = stops[sid] else { continue }
            if k == ids.count - 1 && isLoop {
                assigned.append((sid, length)); break
            }
            let p = plane(stop.coordinate)
            var best: (score: Double, d: Double)? = nil
            for i in 1..<pts.count {
                let a = pts[i - 1], b = pts[i]
                let seg = cum[i] - cum[i - 1]
                if cum[i] < prev { continue }
                let t = seg == 0 ? 0 : max(0, min(1, simd_dot(p - a, b - a) / (seg * seg)))
                let d = cum[i - 1] + seg * t
                if d < prev { continue }
                let perp = simd_distance(p, a + (b - a) * t)
                let score = perp + 0.02 * (d - max(prev, 0))
                if best == nil || score < best!.score { best = (score, d) }
            }
            if let best {
                assigned.append((sid, best.d))
                prev = best.d
            }
        }
        g = RouteGeometry(routeId: g.routeId, points: g.points, cumulative: g.cumulative,
                          length: g.length, isLoop: g.isLoop,
                          stopDistances: assigned.map { (stopId: $0.0, distance: $0.1) },
                          originLat: g.originLat, originLon: g.originLon, mPerDegLon: g.mPerDegLon)
        return g
    }

    /// Nearest point on the whole line. Used for live buses every poll.
    func project(_ c: CLLocationCoordinate2D) -> Projection {
        let p = SIMD2((c.longitude - originLon) * mPerDegLon, (c.latitude - originLat) * mPerDegLat)
        var bestD = 0.0, bestOff = Double.greatestFiniteMagnitude
        for i in 1..<points.count {
            let a = points[i - 1], b = points[i]
            let seg = cumulative[i] - cumulative[i - 1]
            let t = seg == 0 ? 0 : max(0, min(1, simd_dot(p - a, b - a) / (seg * seg)))
            let q = a + (b - a) * t
            let off = simd_distance(p, q)
            if off < bestOff { bestOff = off; bestD = cumulative[i - 1] + seg * t }
        }
        return Projection(distanceAlong: bestD, offsetMeters: bestOff)
    }
}
```

(Add `import simd` if the compiler asks; `SIMD2<Double>` arithmetic needs it on some SDKs.)

- [ ] **Step 4: Run tests → all pass.** If a real-route assertion fails, print the actual numbers first; the fixture is ground truth.

- [ ] **Step 5: Commit**
```bash
git add ios/Bussin/Models/RouteGeometry.swift ios/BussinTests/RouteGeometryTests.swift
git commit -m "Add route geometry: snap positions onto route lines"
```

---

### Task 2: Tracked buses — speed, distance along route, glitch filter

**Files:**
- Create: `ios/Bussin/Models/BusTracker.swift`, `ios/BussinTests/BusTrackerTests.swift`
- Modify: `ios/Bussin/Store/ShuttleStore.swift`

- [ ] **Step 1: Failing tests**

`ios/BussinTests/BusTrackerTests.swift`:

```swift
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

    func testDefaultSpeedAndDistance() throws {
        let gs = try geometries()
        var tracker = BusTracker()
        let g = try XCTUnwrap(gs["74769"])
        // Put a bus exactly at the route's start.
        let bus = LiveBus(id: 1, number: "2146", routeId: "74769",
                          coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                          headingDegrees: nil, ridersAboard: nil, capacity: nil, isStale: false)
        // Fake projection by using a real on-route point instead:
        let onRoute = try XCTUnwrap(gs["74769"]).pointCoordinate(at: 0)
        let b2 = LiveBus(id: 1, number: "2146", routeId: "74769", coordinate: onRoute,
                         headingDegrees: nil, ridersAboard: nil, capacity: nil, isStale: false)
        let tracked = tracker.update(buses: [b2], geometries: gs, at: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(tracked.count, 1)
        XCTAssertEqual(tracked[0].speed, 4.0, accuracy: 0.001, "no history yet — default speed")
        XCTAssertEqual(tracked[0].distanceAlong, 0, accuracy: 30)
        _ = bus
        _ = g
    }

    func testSpeedLearnsFromMovement() throws {
        let gs = try geometries()
        let g = try XCTUnwrap(gs["74769"])
        var tracker = BusTracker()
        let c0 = g.pointCoordinate(at: 0), c1 = g.pointCoordinate(at: 120)  // 120 m apart along the line
        let mk = { (c: CLLocationCoordinate2D) in
            LiveBus(id: 7, number: "x", routeId: "74769", coordinate: c,
                    headingDegrees: nil, ridersAboard: nil, capacity: nil, isStale: false) }
        _ = tracker.update(buses: [mk(c0)], geometries: gs, at: Date(timeIntervalSince1970: 0))
        let t2 = tracker.update(buses: [mk(c1)], geometries: gs, at: Date(timeIntervalSince1970: 20))
        // moved 120 m in 20 s = 6 m/s; blended 0.7*4 + 0.3*6 = 4.6
        XCTAssertEqual(t2[0].speed, 4.6, accuracy: 0.3)
    }

    func testOffCorridorBusIsDropped() throws {
        let gs = try geometries()
        let nh = LiveBus(id: 9, number: "2190", routeId: "74770",
                         coordinate: CLLocationCoordinate2D(latitude: 43.4824178, longitude: -71.5483933),
                         headingDegrees: nil, ridersAboard: nil, capacity: nil, isStale: false)
        var tracker = BusTracker()
        let tracked = tracker.update(buses: [nh], geometries: gs, at: .now)
        XCTAssertTrue(tracked.isEmpty, "a bus 300+ m off its route is a GPS glitch, not a bus")
    }
}
```

- [ ] **Step 2: Verify compile failure**, same command.

- [ ] **Step 3: Implement `ios/Bussin/Models/BusTracker.swift`** (and the small test helper on RouteGeometry):

```swift
import Foundation
import CoreLocation

/// A live bus enriched with everything the ETA math needs.
struct TrackedBus: Identifiable {
    let bus: LiveBus
    let distanceAlong: Double   // meters along its route
    let speed: Double           // m/s, learned from movement between pings
    var id: Int { bus.id }
}

/// Keeps short per-bus history so speed can be learned. Value type on purpose:
/// the store owns one and mutates it on each poll.
struct BusTracker {
    static let defaultSpeed = 4.0          // ~9 mph incl. stops, same as the prototype
    static let maxOffsetMeters = 300.0     // beyond this, the ping is a glitch
    private struct Memory { var distance: Double; var time: Date; var speed: Double }
    private var memory: [Int: Memory] = [:]

    mutating func update(buses: [LiveBus], geometries: [String: RouteGeometry], at now: Date) -> [TrackedBus] {
        var out: [TrackedBus] = []
        for bus in buses {
            guard let g = geometries[bus.routeId] else { continue }
            let proj = g.project(bus.coordinate)
            guard proj.offsetMeters <= Self.maxOffsetMeters else {
                memory[bus.id] = nil        // forget glitching buses; they restart fresh
                continue
            }
            var speed = Self.defaultSpeed
            if let m = memory[bus.id] {
                let dt = now.timeIntervalSince(m.time)
                if dt >= 1, dt <= 90 {
                    let moved = (proj.distanceAlong - m.distance).truncatingRemainder(dividingBy: g.length)
                    let forward = moved < 0 ? moved + g.length : moved
                    let instant = forward / dt
                    if instant < 15 {       // ignore teleports
                        speed = max(1.5, min(9, 0.7 * m.speed + 0.3 * instant))
                    } else { speed = m.speed }
                } else { speed = m.speed }
            }
            memory[bus.id] = Memory(distance: proj.distanceAlong, time: now, speed: speed)
            out.append(TrackedBus(bus: bus, distanceAlong: proj.distanceAlong, speed: speed))
        }
        return out.sorted { $0.id < $1.id }
    }
}

extension RouteGeometry {
    /// Coordinate at a given distance along the line (tests + "bus is here" UI).
    func pointCoordinate(at distance: Double) -> CLLocationCoordinate2D {
        let d = max(0, min(length, distance))
        var i = 1
        while i < cumulative.count - 1 && cumulative[i] < d { i += 1 }
        let seg = cumulative[i] - cumulative[i - 1]
        let t = seg == 0 ? 0 : (d - cumulative[i - 1]) / seg
        let q = points[i - 1] + (points[i] - points[i - 1]) * t
        return CLLocationCoordinate2D(latitude: originLatPublic + q.y / 111_132.0,
                                      longitude: originLonPublic + q.x / mPerDegLonPublic)
    }
}
```

For that extension, expose the origin privately-stored values via internal computed properties on RouteGeometry (`originLatPublic` etc.) or just make the three stored constants `let originLat/originLon/mPerDegLon` non-private. Simplest: make them internal (drop `private`) and use them directly; rename without the `Public` suffix in both places.

- [ ] **Step 4: Wire into `ShuttleStore`.** Modify `ShuttleStore`:
  - Add stored properties: `private var tracker = BusTracker()`, `private(set) var geometries: [String: RouteGeometry] = [:]`, `private(set) var trackedBuses: [TrackedBus] = []`, `private var stopsById: [String: ShuttleStop] = [:]`.
  - In `apply(catalogData:)` after setting `routes`/`stops`: build `stopsById` and `geometries` (`RouteGeometry.build` per route).
  - In `apply(busesData:)` after setting `buses`: `trackedBuses = tracker.update(buses: buses, geometries: geometries, at: .now)` and change `buses` consumers later; keep `buses` for the map for now but have MapScreen read `trackedBuses.map(\.bus)` in Task 6.
  - Add helper `func stop(_ id: String) -> ShuttleStop? { stopsById[id] }`.

- [ ] **Step 5: Run all tests → pass. Commit**
```bash
git add ios/Bussin/Models/BusTracker.swift ios/Bussin/Models/RouteGeometry.swift ios/Bussin/Store/ShuttleStore.swift ios/BussinTests/BusTrackerTests.swift
git commit -m "Track bus speed and distance along route; drop GPS glitches"
```

---

### Task 3: ETAEngine — departures, route arrivals, a bus's upcoming stops

**Files:**
- Create: `ios/Bussin/Models/ETAEngine.swift`, `ios/BussinTests/ETAEngineTests.swift`

- [ ] **Step 1: Failing tests**

`ios/BussinTests/ETAEngineTests.swift`:

```swift
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
        let stop = g.stopDistances[2]       // any mid-route stop
        let b = bus(1, a.id, at: stop.distance - 480, g: g, speed: 4)   // 480 m short of it
        let engine = ETAEngine(geometries: gs, buses: [b])
        let eta = try XCTUnwrap(engine.arrivals(routeId: a.id, stopId: stop.stopId, count: 1).first)
        XCTAssertEqual(eta, 120, accuracy: 10)   // 480 m / 4 m/s
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
            bus(1, a.id, at: dA - 2000, g: gA),   // A: 500 s away
            bus(2, e.id, at: dE - 400, g: gE),    // E: 100 s away
        ])
        let deps = engine.departures(stopId: hub, routeIds: [a.id, e.id])
        XCTAssertEqual(deps.map(\.routeId), [e.id, a.id], "soonest route first")
        XCTAssertEqual(try XCTUnwrap(deps.first?.next), 100, accuracy: 15)
        XCTAssertNil(deps.first?.then, "only one E bus, so no second arrival")
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
```

- [ ] **Step 2: Verify compile failure.**

- [ ] **Step 3: Implement `ios/Bussin/Models/ETAEngine.swift`**

```swift
import Foundation

/// Pure arrival math over geometries + tracked buses. Rebuilt cheaply every poll.
struct ETAEngine {
    let geometries: [String: RouteGeometry]
    let buses: [TrackedBus]

    struct Departure: Identifiable {
        let routeId: String
        let next: Double?           // seconds to the next bus, nil if none running
        let then: Double?           // seconds to the one after
        var id: String { routeId }
    }

    struct UpcomingStop: Identifiable {
        let stopId: String
        let secondsAway: Double
        var id: String { stopId }
    }

    private func forwardGap(from: Double, to: Double, length: Double) -> Double {
        let d = (to - from).truncatingRemainder(dividingBy: length)
        return d < 0 ? d + length : d
    }

    /// Seconds until the next `count` buses of one route reach one stop.
    func arrivals(routeId: String, stopId: String, count: Int = 2) -> [Double] {
        guard let g = geometries[routeId] else { return [] }
        let rbuses = buses.filter { $0.bus.routeId == routeId }
        guard !rbuses.isEmpty else { return [] }
        // A stop can appear twice in a loop's order (first == last): use the first entry.
        guard let sd = g.stopDistances.first(where: { $0.stopId == stopId }) else { return [] }
        var times = rbuses.map { forwardGap(from: $0.distanceAlong, to: sd.distance, length: g.length) / $0.speed }
            .sorted()
        // If more are wanted than buses exist, later laps follow at one full loop each.
        let lap = g.length / BusTracker.defaultSpeed
        var k = 1
        while times.count < count, g.isLoop {
            times.append(contentsOf: rbuses.map {
                forwardGap(from: $0.distanceAlong, to: sd.distance, length: g.length) / $0.speed + Double(k) * lap
            })
            k += 1
        }
        return Array(times.sorted().prefix(count))
    }

    /// One row per route serving a stop, soonest first. Routes with no buses get next == nil.
    func departures(stopId: String, routeIds: [String]) -> [Departure] {
        routeIds.map { rid in
            let t = arrivals(routeId: rid, stopId: stopId, count: 2)
            return Departure(routeId: rid, next: t.first, then: t.count > 1 ? t[1] : nil)
        }
        .sorted { ($0.next ?? .infinity) < ($1.next ?? .infinity) }
    }

    /// Every distinct stop ahead of one bus, in the order it will reach them.
    func upcomingStops(busId: Int) -> [UpcomingStop] {
        guard let b = buses.first(where: { $0.id == busId }),
              let g = geometries[b.bus.routeId] else { return [] }
        let list = g.isLoop ? g.stopDistances.dropLast() : g.stopDistances[...]
        var seen = Set<String>()
        return list.compactMap { sd -> UpcomingStop? in
            guard seen.insert(sd.stopId).inserted else { return nil }
            return UpcomingStop(stopId: sd.stopId,
                                secondsAway: forwardGap(from: b.distanceAlong, to: sd.distance, length: g.length) / b.speed)
        }
        .sorted { $0.secondsAway < $1.secondsAway }
    }
}
```

- [ ] **Step 4: Run tests → pass.** (If `departures` nil-handling or duplicate-stop assumptions fail against the fixture, print actuals and fix the engine, not the fixture.)

- [ ] **Step 5: Expose on the store.** In `ShuttleStore` add:

```swift
var engine: ETAEngine { ETAEngine(geometries: geometries, buses: trackedBuses) }

/// Routes that serve a stop and are actually running right now.
func runningRouteIds(at stop: ShuttleStop) -> [String] {
    stop.routeIds.filter { routesById[$0] != nil && !excludedRouteIds.contains($0) && hasBuses($0) }
}
func hasBuses(_ routeId: String) -> Bool { trackedBuses.contains { $0.bus.routeId == routeId } }
```

- [ ] **Step 6: Full suite → pass. Commit**
```bash
git add ios/Bussin/Models/ETAEngine.swift ios/Bussin/Store/ShuttleStore.swift ios/BussinTests/ETAEngineTests.swift
git commit -m "Add ETA engine: departures, arrivals, upcoming stops"
```

---

### Task 4: Sheet + Home screen 〈model switch: Sonnet from here〉

**Files:**
- Create: `ios/Bussin/Views/SheetHost.swift`, `ios/Bussin/Views/HomeView.swift`, `ios/Bussin/Views/Format.swift`, `ios/Bussin/Views/RowViews.swift`
- Modify: `ios/Bussin/Views/MapScreen.swift`

- [ ] **Step 1: Formatting helpers — `ios/Bussin/Views/Format.swift`**

```swift
import Foundation

enum Fmt {
    /// "Now" under 45 s, else "3 min".
    static func eta(_ seconds: Double) -> String {
        seconds < 45 ? "Now" : "\(Int((seconds / 60).rounded())) min"
    }
    static func minutes(_ seconds: Double) -> String { "\(max(1, Int((seconds / 60).rounded()))) min" }
    static func clock(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "h:mm"; return f.string(from: date)
    }
}
```

- [ ] **Step 2: Navigation + rows.** `ios/Bussin/Views/RowViews.swift`:

```swift
import SwiftUI

enum Place: Hashable {
    case stop(String)
    case route(String)
    case bus(Int)
}

struct RouteBadge: View {
    let letter: String
    let colorHex: String
    var size: CGFloat = 30
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(Color(hex: colorHex))
            .frame(width: size, height: size)
            .overlay(Text(letter).font(.system(size: size * 0.53, weight: .bold))
                .foregroundStyle(Color.textOn(hex: colorHex)))
    }
}

struct LiveLabel: View {
    let text: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "dot.radiowaves.up.forward").font(.caption2.weight(.bold))
            Text(text)
        }
        .font(.headline)
        .foregroundStyle(.green)
    }
}

/// One departure row: badge, route name + direction, right-aligned live ETA.
struct DepartureRow: View {
    let route: ShuttleRoute
    let next: Double?
    let then: Double?
    var body: some View {
        HStack(spacing: 12) {
            RouteBadge(letter: route.letter, colorHex: route.colorHex)
            VStack(alignment: .leading, spacing: 1) {
                Text(route.name).font(.headline)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                if let next { LiveLabel(text: Fmt.eta(next)) }
                if let then { Text("then \(Fmt.minutes(then))").font(.footnote).foregroundStyle(.secondary) }
            }
        }
        .padding(.vertical, 4)
    }
}
```

- [ ] **Step 3: Home — `ios/Bussin/Views/HomeView.swift`**

```swift
import SwiftUI
import CoreLocation

struct HomeView: View {
    let store: ShuttleStore
    let userCoordinate: CLLocationCoordinate2D?

    /// 715 Broadway stands in until location arrives (matches PRODUCT.md).
    private var nearestStop: ShuttleStop? {
        let from = userCoordinate ?? CLLocationCoordinate2D(latitude: 40.72927, longitude: -73.99394)
        return store.stops.filter { !store.runningRouteIds(at: $0).isEmpty }
            .min(by: { d($0.coordinate, from) < d($1.coordinate, from) })
            ?? store.stop("6545")
    }
    private func d(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let dx = (a.longitude - b.longitude) * 85_000, dy = (a.latitude - b.latitude) * 111_000
        return dx * dx + dy * dy
    }

    var body: some View {
        List {
            if let stop = nearestStop {
                Section("Nearest Stop") {
                    NavigationLink(value: Place.stop(stop.id)) {
                        HStack(spacing: 12) {
                            Image(systemName: "bus.fill").font(.title3).foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(.blue, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            VStack(alignment: .leading) {
                                Text(stop.name).font(.headline)
                                Text("Shuttle stop").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    let deps = store.engine.departures(stopId: stop.id, routeIds: store.runningRouteIds(at: stop))
                    ForEach(deps) { dep in
                        if let route = store.route(for: dep.routeId) {
                            NavigationLink(value: Place.route(route.id)) {
                                DepartureRow(route: route, next: dep.next, then: dep.then)
                            }
                        }
                    }
                }
            }
            Section("All Routes") {
                ForEach(store.routes) { route in
                    NavigationLink(value: Place.route(route.id)) {
                        HStack(spacing: 12) {
                            RouteBadge(letter: route.letter, colorHex: route.colorHex)
                                .opacity(store.hasBuses(route.id) ? 1 : 0.45)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(route.name)
                                Text(store.hasBuses(route.id)
                                     ? "\(store.trackedBuses.filter { $0.bus.routeId == route.id }.count) buses running"
                                     : "Not running now")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("Bussin")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

- [ ] **Step 4: Sheet host — `ios/Bussin/Views/SheetHost.swift`**

```swift
import SwiftUI
import CoreLocation

struct SheetHost: View {
    let store: ShuttleStore
    @Binding var path: NavigationPath
    let userCoordinate: CLLocationCoordinate2D?

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(store: store, userCoordinate: userCoordinate)
                .navigationDestination(for: Place.self) { place in
                    switch place {
                    case .stop(let id): StopView(store: store, stopId: id)
                    case .route(let id): RouteView(store: store, routeId: id)
                    case .bus(let id): BusView(store: store, busId: id)
                    }
                }
        }
        .presentationDetents([.height(140), .fraction(0.48), .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.48)))
        .presentationBackground(.regularMaterial)
        .interactiveDismissDisabled()
    }
}
```

(Until Task 5 exists, add placeholder `StopView`/`RouteView`/`BusView` structs showing `Text(id)` in this same file, then delete them in Task 5 — the build must stay green at every step.)

- [ ] **Step 5: Present it from `MapScreen`.** Modify MapScreen: add `@State private var path = NavigationPath()`, `@State private var sheetShown = true`, and `.sheet(isPresented: $sheetShown) { SheetHost(store: store, path: $path, userCoordinate: locationManager.location?.coordinate) }`. Make `store` shared: `MapScreen` keeps `@State private var store = ShuttleStore()` and passes it down.

- [ ] **Step 6: Build, screenshot home (light), eyeball:** departures show green "N min" rows for routes with buses; routes without buses say "Not running now" with a dimmed badge. Run full test suite.

- [ ] **Step 7: Commit**
```bash
git add ios/Bussin/Views/SheetHost.swift ios/Bussin/Views/HomeView.swift ios/Bussin/Views/Format.swift ios/Bussin/Views/RowViews.swift ios/Bussin/Views/MapScreen.swift
git commit -m "Add bottom sheet with Home: nearest stop departures and all routes"
```

---

### Task 5: Stop and Route screens + map focus

**Files:**
- Create: `ios/Bussin/Views/StopView.swift`, `ios/Bussin/Views/RouteView.swift`
- Modify: `ios/Bussin/Views/SheetHost.swift` (remove placeholders), `ios/Bussin/Views/MapScreen.swift`

- [ ] **Step 1: `ios/Bussin/Views/StopView.swift`**

```swift
import SwiftUI

struct StopView: View {
    let store: ShuttleStore
    let stopId: String

    var body: some View {
        List {
            if let stop = store.stop(stopId) {
                Section("Departures") {
                    let running = store.runningRouteIds(at: stop)
                    if running.isEmpty {
                        Text("No buses running here right now.").foregroundStyle(.secondary)
                    }
                    ForEach(store.engine.departures(stopId: stopId, routeIds: running)) { dep in
                        if let route = store.route(for: dep.routeId) {
                            NavigationLink(value: Place.route(route.id)) {
                                DepartureRow(route: route, next: dep.next, then: dep.then)
                            }
                        }
                    }
                }
                let off = stop.routeIds.filter { store.route(for: $0) != nil && !store.hasBuses($0) }
                if !off.isEmpty {
                    Section {
                        Text("\(off.compactMap { store.route(for: $0)?.name }.joined(separator: ", ")) also stops here, but isn't running right now.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle(store.stop(stopId)?.name ?? "Stop")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

- [ ] **Step 2: `ios/Bussin/Views/RouteView.swift`** — the timeline:

```swift
import SwiftUI

struct RouteView: View {
    let store: ShuttleStore
    let routeId: String

    var body: some View {
        List {
            if let route = store.route(for: routeId), let g = store.geometries[routeId] {
                let stopsOnLine = g.isLoop ? g.stopDistances.dropLast() : g.stopDistances[...]
                let buses = store.trackedBuses.filter { $0.bus.routeId == routeId }
                Section(header: header(route, buses.count)) {
                    ForEach(Array(stopsOnLine.enumerated()), id: \.offset) { _, sd in
                        if let stop = store.stop(sd.stopId) {
                            NavigationLink(value: Place.stop(stop.id)) {
                                HStack(spacing: 14) {
                                    Circle().fill(.white)
                                        .stroke(Color(hex: route.colorHex), lineWidth: 4)
                                        .frame(width: 14, height: 14)
                                    Text(stop.name)
                                    Spacer()
                                    if let t = store.engine.arrivals(routeId: routeId, stopId: stop.id, count: 1).first {
                                        LiveLabel(text: Fmt.eta(t))
                                    }
                                }
                            }
                        }
                        // buses currently between this stop and the next
                        ForEach(busesBetween(sd: sd, stops: Array(stopsOnLine), buses: buses, g: g)) { tb in
                            NavigationLink(value: Place.bus(tb.id)) {
                                HStack(spacing: 14) {
                                    RouteBadge(letter: route.letter, colorHex: route.colorHex, size: 24)
                                    Text("Bus \(tb.bus.number)").font(.subheadline).foregroundStyle(.secondary)
                                    if let riders = tb.bus.ridersAboard, let cap = tb.bus.capacity {
                                        Text("· \(riders) of \(cap) aboard").font(.footnote).foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle(store.route(for: routeId)?.name ?? "Route")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(_ route: ShuttleRoute, _ n: Int) -> some View {
        Text(n > 0 ? "\(n) buses running" : "Not running now")
    }

    private func busesBetween(sd: (stopId: String, distance: Double),
                              stops: [(stopId: String, distance: Double)],
                              buses: [TrackedBus], g: RouteGeometry) -> [TrackedBus] {
        let next = stops.first { $0.distance > sd.distance }?.distance ?? g.length
        return buses.filter { $0.distanceAlong >= sd.distance && $0.distanceAlong < next }
    }
}
```

- [ ] **Step 3: Map focus.** In MapScreen, watch the navigation path's top element (pass a `focus: Place?` down from SheetHost via a binding, set in `.navigationDestination` appear/disappear — simplest: store an `@State var focus: Place?` in MapScreen, give SheetHost `@Binding var focus`, and set it in each view's `.onAppear`/`.onDisappear`). On focus:
  - `.route(id)` / `.bus(id)`: dim other routes' polylines to 0.15 opacity and other buses to 0.2; camera: `position = .region(regionFitting(route.coordinates))`.
  - `.stop(id)`: camera centers the stop; buses of other routes dim.
  Implement `regionFitting(_ coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion` by min/max lat/lng plus 30% padding.

- [ ] **Step 4: Build, navigate Home → route → stop in the simulator, screenshot each.** Check: timeline ETAs increase down the line; bus rows appear between the right stops; map dims and frames the chosen route.

- [ ] **Step 5: Commit**
```bash
git add ios/Bussin/Views/StopView.swift ios/Bussin/Views/RouteView.swift ios/Bussin/Views/SheetHost.swift ios/Bussin/Views/MapScreen.swift
git commit -m "Add stop and route screens with live timeline and map focus"
```

---

### Task 6: Bus screen + marker interactions

**Files:**
- Create: `ios/Bussin/Views/BusView.swift`
- Modify: `ios/Bussin/Views/MapScreen.swift`

- [ ] **Step 1: `ios/Bussin/Views/BusView.swift`** — the screen from the prototype's bus view:

```swift
import SwiftUI

struct BusView: View {
    let store: ShuttleStore
    let busId: Int

    var body: some View {
        List {
            if let tb = store.trackedBuses.first(where: { $0.id == busId }),
               let route = store.route(for: tb.bus.routeId) {
                if let riders = tb.bus.ridersAboard, let cap = tb.bus.capacity {
                    Section {
                        HStack {
                            Image(systemName: "person.2.fill").foregroundStyle(.secondary)
                            Text("\(riders) of \(cap) aboard")
                            Spacer()
                            Text(riders >= cap - 5 ? "Nearly full" : "Seats open")
                                .font(.footnote).foregroundStyle(riders >= cap - 5 ? .orange : .secondary)
                        }
                    }
                }
                Section("Upcoming stops") {
                    ForEach(store.engine.upcomingStops(busId: busId)) { up in
                        if let stop = store.stop(up.stopId) {
                            NavigationLink(value: Place.stop(stop.id)) {
                                HStack(spacing: 14) {
                                    Circle().fill(.white)
                                        .stroke(Color(hex: route.colorHex), lineWidth: 4)
                                        .frame(width: 14, height: 14)
                                    Text(stop.name)
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 1) {
                                        Text(Fmt.clock(Date.now.addingTimeInterval(up.secondsAway)))
                                            .font(.headline).monospacedDigit()
                                        Text(up.secondsAway < 45 ? "Arriving" : "in \(Fmt.minutes(up.secondsAway))")
                                            .font(.footnote).foregroundStyle(.green)
                                    }
                                }
                            }
                        }
                    }
                }
                Section {
                    Text("Times assume the bus keeps its current pace. They update every few seconds from the live feed.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                Text("This bus went out of service.").foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle(busTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var busTitle: String {
        store.trackedBuses.first(where: { $0.id == busId }).map { "Bus \($0.bus.number)" } ?? "Bus"
    }
}
```

- [ ] **Step 2: Marker taps + z-order in MapScreen.**
  - Replace the plain `BusMarker` annotation content with a `Button` that appends `Place.bus(bus.id)` to the path; same for stop dots (`Place.stop`). Give stop-dot buttons a 32×32 hit area via `.frame` + `.contentShape(Circle())` (DESIGN.md's 44pt rule is relaxed only on dense map dots, matching Apple Maps).
  - Selected bus (`focus == .bus(id)`): scale its marker to 34 pt with a blue halo (`.shadow(color: .blue.opacity(0.4), radius: 6)`); dim unrelated buses.
  - Z-order: declare annotations in paint order — stops first, then buses, then `UserAnnotation()` **last** so your dot draws on top (the phase-1 bug).
- [ ] **Step 3: Live countdown refresh.** The engine reads `Date.now` lazily; SwiftUI re-renders on each poll because `trackedBuses` changes every 4 s — no timer needed. Verify by watching a departure row tick down in the simulator.
- [ ] **Step 4: Build; in the simulator tap a bus marker → bus screen; tap a listed stop → stop screen; back-swipe works. Screenshot bus screen light + dark.**
- [ ] **Step 5: Full test suite → pass. Commit**
```bash
git add ios/Bussin/Views/BusView.swift ios/Bussin/Views/MapScreen.swift
git commit -m "Add bus screen with upcoming stops; tappable markers; fix marker z-order"
```

---

### Task 7: Verify, document, merge

- [ ] **Step 1: Screenshot pass** (iPhone 17 sim): Home medium detent, Route view, Bus view — each in light and dark (`xcrun simctl ui "iPhone 17" appearance dark`). Check against DESIGN.md: answer-is-biggest, three voices only, 44 pt targets, both themes legible.
- [ ] **Step 2: Full suite** one final time: expect 9 old + ~10 new tests green.
- [ ] **Step 3: Docs.** README "Where it stands": add arrival times + screens line. Build log entry in `docs/index.html` (humanize voice). Update the build-map artifact: phase 2 stops → done, bus moves to phase 3.
- [ ] **Step 4: Merge** via superpowers:finishing-a-development-branch (tests → options → user choice).

---

## Self-review

- **Spec coverage:** ETA engine ✓ (T1–T3, incl. self-correcting speed and the 300 m off-corridor filter), sheet + detents ✓ (T4), Home/Stop/Route/Bus ✓ (T4–T6), marker z-fix ✓ (T6), honest-data footnote ✓ (T6), crowding surfaced on the bus screen ✓ (T6, from the feed-extras spec section). Favorites and search are phase 3 by design.
- **Placeholders:** T4's temporary Stop/Route/Bus stubs are explicit and deleted in T5; no TBDs.
- **Type consistency:** `TrackedBus.id == bus.id` (Int) used by `Place.bus(Int)`, `upcomingStops(busId:)`, marker taps; `stopDistances` tuple shape matches between RouteGeometry, ETAEngine, RouteView; `store.geometries` exposed read-only for RouteView; `Fmt.eta/minutes/clock` match all call sites.
- **Known risks:** `.presentationBackgroundInteraction` detent behavior differs subtly across iOS versions — verify map pans behind the medium detent in the sim; List inside a sheet with `.height(140)` shows only the nav bar — acceptable peek state. SwiftUI `Circle().fill().stroke()` needs iOS 17+ (we're 18). If `simd` ops complain, `import simd`.
