# Bussin iOS Phase 3 — Trip Planning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A rider types any address or place, and the app says whether a shuttle beats walking, which bus to catch, and where to get on and off. Favorites and the two latest searches sit on the home screen. The app runs on Chris's iPhone.

**Architecture:** `TripPlanner` is a pure port of the prototype's `plan()`, working on the same `RouteGeometry` and `TrackedBus` values the ETA engine uses. `PlaceSearch` wraps Apple's `MKLocalSearchCompleter`. `SavedPlaces` keeps favorites and recents in `UserDefaults`. Two new sheet screens (Search, Trip) join the existing navigation stack through new `Place` cases, and the map draws the chosen trip.

**Tech Stack:** Swift, SwiftUI, MapKit (`MKLocalSearchCompleter`, `MKLocalSearch`), XCTest. No new dependencies.

**Conventions (same as phases 1–2):** work on branch `ios-phase-3`; after any file add/remove run `cd ios && xcodegen generate`; test with `xcodebuild test -project ios/Bussin.xcodeproj -scheme Bussin -destination 'platform=iOS Simulator,name=iPhone 17'`; `git add` only named files; follow DESIGN.md (blue = interaction, green = live, red = alert).

**Models:** Fable/Opus for Tasks 1–2 (planner math). Sonnet for Tasks 3–7 (screens). Haiku for Task 9 chores.

## Decisions made with Chris (Nov 11)

1. **Search is Apple Maps search, not a curated list.** Any address or restaurant. This replaces the spec line that parked `MKLocalSearch` for later. Results are biased to the area the shuttles cover.
2. **Home shows favorites first, then the two most recent searches that aren't favorites.**
3. **Walking times on the trip screen are real street routes from Apple Maps**, the same numbers Apple Maps would give for walking. Straight-line estimates are only a first guess while Apple answers, and a fallback when Apple can't be reached.

## How real walking times fit in

Apple limits how many walking routes an app may request (roughly 50 a minute), and a single trip has hundreds of possible board/alight pairs. So the planner works in two passes:

1. **Shortlist with estimates.** The fast straight-line math picks the best board/alight pair on each running route. This is instant.
2. **Re-time with Apple.** `WalkTimes` asks Apple for the real walk on at most 9 legs: the whole-way walk, plus the walk to the stop and from the stop for up to four shortlisted routes. The planner then recomputes each option with the real numbers (a longer real walk can mean catching a later bus), compares against the real whole-way walk, and re-sorts.

Answers are cached, so the 4-second bus refresh never re-asks Apple. Until the real numbers land (about a second), times show with "about". The map draws the real walking path. Home's one-line summaries under favorites stay estimates, marked "about", so opening the app doesn't fire dozens of Apple requests.

## Where this departs from the prototype's `plan()`, and why

- **Each bus uses its own learned speed** for wait and ride time. The prototype used a flat 4 m/s.
- **Loops wrap.** On a loop you can board at a late stop and get off at an early one. The prototype only looked forward in the stop list.
- **The last walk is capped at 20 minutes.** With any address allowed, someone will search for a place in Queens. Without the cap the planner would suggest a shuttle followed by a two-hour walk.
- **"Too far" verdict.** If no shuttle helps and walking takes over 45 minutes, the app says the shuttles don't go there and offers Apple Maps, instead of telling the rider to walk for three hours.
- **Plans refresh with every bus update** (every 4 seconds). The prototype froze a plan and counted down.
- **Privacy:** analytics record the route and the board/alight stops, never the searched address. Someone's home address should not land in PostHog.

## File map

| File | Job |
|---|---|
| `ios/Bussin/Models/TripPlanner.swift` (new) | `Walk` distance/time helper and the planner |
| `ios/Bussin/Models/Destination.swift` (new) | A searched place: name, subtitle, coordinate |
| `ios/Bussin/Store/SavedPlaces.swift` (new) | Favorites and recents, saved on the phone |
| `ios/Bussin/Store/PlaceSearch.swift` (new) | Apple search suggestions and lookup |
| `ios/Bussin/Store/WalkTimes.swift` (new) | Real walking times and paths from Apple Maps, cached |
| `ios/Bussin/Views/SearchView.swift` (new) | Search field and results |
| `ios/Bussin/Views/TripView.swift` (new) | The answer: shuttle options, walking, steps |
| `ios/Bussin/Views/RowViews.swift` | `Place` gains `.search` and `.trip` |
| `ios/Bussin/Views/SheetHost.swift`, `HomeView.swift`, `MapScreen.swift` | Wiring, home rows, trip drawn on the map |
| `ios/Bussin/Store/ShuttleStore.swift`, `App/Analytics.swift` | `planner` accessor, two new events |
| `ios/BussinTests/TripPlannerTests.swift`, `SavedPlacesTests.swift` (new) | Tests |

---

### Task 1: Walk helper and TripPlanner

**Files:** Create `ios/Bussin/Models/TripPlanner.swift`, `ios/BussinTests/TripPlannerTests.swift`. Modify `ios/Bussin/Store/ShuttleStore.swift`, `ios/Bussin/Views/HomeView.swift`.

- [ ] **Step 1: Write the failing tests**

`ios/BussinTests/TripPlannerTests.swift`:

```swift
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
```

- [ ] **Step 2: Run and confirm they fail to compile** (`Walk` and `TripPlanner` don't exist yet).

- [ ] **Step 3: Implement**

`ios/Bussin/Models/TripPlanner.swift`:

```swift
import Foundation
import CoreLocation

/// Walking estimates: straight line × 1.25 for the street grid, at 1.3 m/s. Same as the prototype.
enum Walk {
    static let metersPerSecond = 1.3
    static let detour = 1.25

    static func meters(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let dx = (a.longitude - b.longitude) * 111_320 * cos(a.latitude * .pi / 180)
        let dy = (a.latitude - b.latitude) * 111_132
        return (dx * dx + dy * dy).squareRoot() * detour
    }

    static func seconds(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        meters(a, b) / metersPerSecond
    }
}

/// One real walk from Apple Maps.
struct WalkLeg: Equatable {
    let seconds: Double
    let meters: Double
}

/// Real walks already fetched from Apple Maps. Returns nil for a leg that isn't known yet.
typealias WalkLookup = (CLLocationCoordinate2D, CLLocationCoordinate2D) -> WalkLeg?

/// Shuttle versus walking. Pure: same inputs as ETAEngine, rebuilt every poll.
struct TripPlanner {
    static let maxWalkToStop = 12 * 60.0      // won't send you further than this to board
    static let maxWalkFromStop = 20 * 60.0    // or further than this after getting off
    static let boardingBuffer = 30.0          // be at the stop this long before the bus
    static let mustBeatWalkingBy = 60.0       // a shuttle that saves under a minute isn't worth it
    static let tooFarToWalk = 45 * 60.0
    static let nearDestination = 5 * 60.0     // "also stops near here" radius

    let geometries: [String: RouteGeometry]
    let stops: [String: ShuttleStop]
    let buses: [TrackedBus]

    struct Option: Identifiable, Equatable {
        let routeId: String
        let boardStopId: String
        let alightStopId: String
        let walkToStop: Double      // seconds
        let busArrives: Double      // seconds from now until the bus reaches the boarding stop
        let ride: Double
        let walkFromStop: Double
        let total: Double           // busArrives + ride + walkFromStop
        let stopCount: Int
        let isEstimate: Bool        // true until both walks are real Apple Maps times
        var id: String { routeId }
    }

    enum Verdict { case shuttle, walk, tooFar }

    struct Plan {
        let options: [Option]           // best per route, fastest first, at most 3
        let walkSeconds: Double
        let walkMeters: Double
        let verdict: Verdict
        let idleRouteIds: [String]      // routes with a stop near the destination but no buses out
        let isEstimate: Bool            // true while any number shown is still a straight-line guess
    }

    /// The best pair per running route by estimate, before comparing with walking.
    /// These are the legs worth asking Apple about.
    func candidates(from origin: CLLocationCoordinate2D, to dest: CLLocationCoordinate2D) -> [Option] {
        Array(Set(buses.map(\.bus.routeId)).sorted()
            .compactMap { bestOption(routeId: $0, from: origin, to: dest) }
            .sorted { $0.total < $1.total }
            .prefix(4))
    }

    func plan(from origin: CLLocationCoordinate2D, to dest: CLLocationCoordinate2D,
              walks: WalkLookup = { _, _ in nil }) -> Plan {
        let realWalk = walks(origin, dest)
        let walk = realWalk?.seconds ?? Walk.seconds(origin, dest)
        let running = Set(buses.map(\.bus.routeId))
        let options = running.sorted()
            .compactMap { bestOption(routeId: $0, from: origin, to: dest, walks: walks) }
            .filter { $0.total < walk - Self.mustBeatWalkingBy && $0.walkFromStop < walk }
            .sorted { $0.total < $1.total }
            .prefix(3)

        let idle = Set(stops.values
            .filter { Walk.seconds($0.coordinate, dest) < Self.nearDestination }
            .flatMap(\.routeIds))
            .filter { geometries[$0] != nil && !running.contains($0) }
            .sorted()

        let verdict: Verdict = !options.isEmpty ? .shuttle : (walk > Self.tooFarToWalk ? .tooFar : .walk)
        return Plan(options: Array(options), walkSeconds: walk,
                    walkMeters: realWalk?.meters ?? Walk.meters(origin, dest),
                    verdict: verdict, idleRouteIds: idle,
                    isEstimate: realWalk == nil || options.contains { $0.isEstimate })
    }

    /// The fastest board/alight pair on one route, before comparing against walking.
    /// The pair is chosen with estimates; its times are then redone with any real walks known.
    func bestOption(routeId: String, from origin: CLLocationCoordinate2D,
                    to dest: CLLocationCoordinate2D, walks: WalkLookup = { _, _ in nil }) -> Option? {
        guard let g = geometries[routeId] else { return nil }
        let rbuses = buses.filter { $0.bus.routeId == routeId }
        guard !rbuses.isEmpty else { return nil }
        // A loop lists its first stop again at the end; drop the repeat so each entry is one visit.
        let entries = g.isLoop ? Array(g.stopDistances.dropLast()) : g.stopDistances
        var best: Option?
        var bestBoardDistance = 0.0, bestRideMeters = 0.0

        for (i, b) in entries.enumerated() {
            guard let boardStop = stops[b.stopId] else { continue }
            let w1 = Walk.seconds(origin, boardStop.coordinate)
            guard w1 <= Self.maxWalkToStop,
                  let caught = firstCatchable(rbuses, at: b.distance, on: g, notBefore: w1 + Self.boardingBuffer)
            else { continue }

            for (j, a) in entries.enumerated() where a.stopId != b.stopId {
                if !g.isLoop && j <= i { continue }        // a one-way line never comes back
                guard let alightStop = stops[a.stopId] else { continue }
                let w2 = Walk.seconds(alightStop.coordinate, dest)
                guard w2 <= Self.maxWalkFromStop else { continue }
                var rideMeters = a.distance - b.distance
                if rideMeters < 0 { rideMeters += g.length }   // through the start of the loop
                let ride = rideMeters / caught.speed
                let total = caught.time + ride + w2
                if best == nil || total < best!.total {
                    best = Option(routeId: routeId, boardStopId: b.stopId, alightStopId: a.stopId,
                                  walkToStop: w1, busArrives: caught.time, ride: ride, walkFromStop: w2,
                                  total: total, stopCount: j > i ? j - i : j - i + entries.count,
                                  isEstimate: true)
                    bestBoardDistance = b.distance
                    bestRideMeters = rideMeters
                }
            }
        }

        // Redo the chosen pair's clock with real walks, where Apple has answered.
        guard let pick = best, let boardStop = stops[pick.boardStopId], let alightStop = stops[pick.alightStopId]
        else { return nil }
        let real1 = walks(origin, boardStop.coordinate), real2 = walks(alightStop.coordinate, dest)
        guard real1 != nil || real2 != nil else { return pick }
        let w1 = real1?.seconds ?? pick.walkToStop, w2 = real2?.seconds ?? pick.walkFromStop
        // A longer real walk to the stop can mean the bus you'd planned on is gone.
        guard let caught = firstCatchable(rbuses, at: bestBoardDistance, on: g, notBefore: w1 + Self.boardingBuffer)
        else { return nil }
        let ride = bestRideMeters / caught.speed
        return Option(routeId: routeId, boardStopId: pick.boardStopId, alightStopId: pick.alightStopId,
                      walkToStop: w1, busArrives: caught.time, ride: ride, walkFromStop: w2,
                      total: caught.time + ride + w2, stopCount: pick.stopCount,
                      isEstimate: real1 == nil || real2 == nil)
    }

    /// The first bus to reach `distance` no sooner than `notBefore` seconds from now.
    /// On a loop a bus you just missed comes round again, so later laps count too.
    private func firstCatchable(_ rbuses: [TrackedBus], at distance: Double, on g: RouteGeometry,
                                notBefore: Double) -> (time: Double, speed: Double)? {
        var best: (time: Double, speed: Double)?
        for bus in rbuses {
            var gap = (distance - bus.distanceAlong).truncatingRemainder(dividingBy: g.length)
            if gap < 0 { gap += g.length }
            for lap in 0...(g.isLoop ? 3 : 0) {
                let t = (gap + Double(lap) * g.length) / bus.speed
                if t >= notBefore {
                    if best == nil || t < best!.time { best = (t, bus.speed) }
                    break
                }
            }
        }
        return best
    }
}
```

In `ShuttleStore.swift`, under `var engine`:

```swift
    var planner: TripPlanner { TripPlanner(geometries: geometries, stops: stopsById, buses: trackedBuses) }
```

In `HomeView.swift`, delete `squaredMeters` and use `Walk`: `nearestStop` compares `Walk.meters($0.coordinate, from)`, and `walkText` becomes `"Shuttle stop · \(Fmt.minutes(Walk.seconds(me, stop.coordinate))) walk"`.

- [ ] **Step 4: `xcodegen generate`, run all tests.** Expected: 21 old tests plus 10 new, all pass. The assertions lean on the real Route A fixture; if one fails, print the option and work out whether the planner or the test's assumption about the route is wrong before changing either.

- [ ] **Step 5: Commit** — `Add the trip planner: shuttle against walking for any destination`

### Task 2: Destination and SavedPlaces

**Files:** Create `ios/Bussin/Models/Destination.swift`, `ios/Bussin/Store/SavedPlaces.swift`, `ios/BussinTests/SavedPlacesTests.swift`.

- [ ] **Step 1: Failing tests**

```swift
import XCTest
@testable import Bussin

@MainActor
final class SavedPlacesTests: XCTestCase {
    private var defaults: UserDefaults!
    override func setUp() {
        defaults = UserDefaults(suiteName: "SavedPlacesTests")
        defaults.removePersistentDomain(forName: "SavedPlacesTests")
    }

    private func place(_ name: String) -> Destination {
        Destination(name: name, subtitle: "New York", latitude: 40.73, longitude: -73.99)
    }

    func testFavoritesToggleAndSurviveRelaunch() {
        let saved = SavedPlaces(defaults: defaults)
        saved.toggleFavorite(place("Tandon"))
        XCTAssertTrue(saved.isFavorite(place("Tandon")))
        XCTAssertEqual(SavedPlaces(defaults: defaults).favorites.map(\.name), ["Tandon"])
        saved.toggleFavorite(place("Tandon"))
        XCTAssertTrue(SavedPlaces(defaults: defaults).favorites.isEmpty)
    }

    func testHomeRecentsAreTheTwoNewestNonFavorites() {
        let saved = SavedPlaces(defaults: defaults)
        ["Joe's Pizza", "Bobst", "Tandon", "Palladium"].forEach { saved.noteSearched(place($0)) }
        saved.toggleFavorite(place("Palladium"))
        XCTAssertEqual(saved.homeRecents.map(\.name), ["Tandon", "Bobst"])
    }

    func testSearchingAgainMovesAPlaceToTheFrontWithoutDuplicating() {
        let saved = SavedPlaces(defaults: defaults)
        ["Bobst", "Tandon", "Bobst"].forEach { saved.noteSearched(place($0)) }
        XCTAssertEqual(saved.recents.map(\.name), ["Bobst", "Tandon"])
    }

    func testRecentsAreCapped() {
        let saved = SavedPlaces(defaults: defaults)
        (1...15).forEach { saved.noteSearched(place("Place \($0)")) }
        XCTAssertEqual(saved.recents.count, SavedPlaces.maxRecents)
        XCTAssertEqual(saved.recents.first?.name, "Place 15")
    }
}
```

- [ ] **Step 2: Run, confirm compile failure.**

- [ ] **Step 3: Implement**

`Destination.swift`:

```swift
import Foundation
import CoreLocation

/// Somewhere a rider searched for. Small and Codable so it can be saved as a favorite.
struct Destination: Hashable, Codable, Identifiable {
    let name: String
    let subtitle: String
    let latitude: Double
    let longitude: Double

    var id: String { "\(name)|\(latitude)|\(longitude)" }
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
}
```

`SavedPlaces.swift`:

```swift
import Foundation
import Observation

/// Favorites and recent searches. Lives on the phone only (UserDefaults); nothing is uploaded.
@Observable @MainActor
final class SavedPlaces {
    static let maxRecents = 10
    private(set) var favorites: [Destination]
    private(set) var recents: [Destination]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        favorites = Self.load("favorites", defaults)
        recents = Self.load("recents", defaults)
    }

    func isFavorite(_ d: Destination) -> Bool { favorites.contains(d) }

    func toggleFavorite(_ d: Destination) {
        if let i = favorites.firstIndex(of: d) { favorites.remove(at: i) } else { favorites.append(d) }
        save("favorites", favorites)
    }

    func noteSearched(_ d: Destination) {
        recents.removeAll { $0 == d }
        recents.insert(d, at: 0)
        recents = Array(recents.prefix(Self.maxRecents))
        save("recents", recents)
    }

    /// What Home shows under the favorites.
    var homeRecents: [Destination] { Array(recents.filter { !favorites.contains($0) }.prefix(2)) }

    private static func load(_ key: String, _ defaults: UserDefaults) -> [Destination] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Destination].self, from: data)) ?? []
    }

    private func save(_ key: String, _ value: [Destination]) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }
}
```

- [ ] **Step 4: `xcodegen generate`, run tests, all pass.**
- [ ] **Step 5: Commit** — `Save favorite places and recent searches on the phone`

### Task 3: Apple place search

**Files:** Create `ios/Bussin/Store/PlaceSearch.swift`. No unit tests: it is a thin wrapper around Apple's network search, checked by hand in Task 8.

```swift
import Foundation
import MapKit
import Observation

/// Type-ahead suggestions from Apple Maps, biased to where the shuttles run.
@Observable @MainActor
final class PlaceSearch: NSObject, MKLocalSearchCompleterDelegate {
    private(set) var suggestions: [MKLocalSearchCompletion] = []
    private(set) var failed = false
    var query = "" {
        didSet {
            let q = query.trimmingCharacters(in: .whitespaces)
            if q.isEmpty { suggestions = []; failed = false } else { completer.queryFragment = q }
        }
    }

    /// Washington Square to MetroTech to Langone, with room around it.
    static let serviceArea = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.722, longitude: -73.985),
        span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.10))

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.region = Self.serviceArea
        completer.resultTypes = [.address, .pointOfInterest]
    }

    /// Turn a tapped suggestion into a place with a coordinate.
    func resolve(_ completion: MKLocalSearchCompletion) async -> Destination? {
        let request = MKLocalSearch.Request(completion: completion)
        request.region = Self.serviceArea
        guard let item = try? await MKLocalSearch(request: request).start().mapItems.first else { return nil }
        let c = item.placemark.coordinate
        return Destination(name: item.name ?? completion.title, subtitle: completion.subtitle,
                           latitude: c.latitude, longitude: c.longitude)
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in self.suggestions = results; self.failed = false }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in self.suggestions = []; self.failed = true }
    }
}
```

- [ ] `xcodegen generate`, build, commit — `Search any address or place through Apple Maps`

### Task 3b: Real walking times from Apple Maps

**Files:** Create `ios/Bussin/Store/WalkTimes.swift`, `ios/BussinTests/WalkTimesTests.swift`.

- [ ] **Step 1: Failing test** for the one pure piece, the cache key (the Apple request itself is checked by hand in Task 8):

```swift
import XCTest
import CoreLocation
@testable import Bussin

final class WalkTimesTests: XCTestCase {
    func testAFewStepsDoNotChangeTheCacheKeyButABlockDoes() {
        let stop = CLLocationCoordinate2D(latitude: 40.69430, longitude: -73.98650)
        let me = CLLocationCoordinate2D(latitude: 40.72951, longitude: -73.99651)
        let fewSteps = CLLocationCoordinate2D(latitude: 40.72953, longitude: -73.99653)      // ~3 m on
        let nextBlock = CLLocationCoordinate2D(latitude: 40.73050, longitude: -73.99651)     // ~110 m on
        XCTAssertEqual(WalkTimes.key(me, stop), WalkTimes.key(fewSteps, stop))
        XCTAssertNotEqual(WalkTimes.key(me, stop), WalkTimes.key(nextBlock, stop))
        XCTAssertNotEqual(WalkTimes.key(me, stop), WalkTimes.key(stop, me), "direction matters")
    }
}
```

- [ ] **Step 2: Implement**

```swift
import Foundation
import MapKit
import Observation

/// Real walking routes from Apple Maps, remembered so each leg is asked for once.
/// Apple throttles an app at roughly 50 requests a minute; a trip needs at most 9.
@Observable @MainActor
final class WalkTimes {
    private var legs: [String: WalkLeg] = [:]
    private var paths: [String: [CLLocationCoordinate2D]] = [:]
    @ObservationIgnored private var inFlight: Set<String> = []
    @ObservationIgnored private var pausedUntil = Date.distantPast

    /// Snaps both ends to a ~50 m grid, so walking a few steps doesn't trigger a new request.
    nonisolated static func key(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> String {
        func snap(_ c: CLLocationCoordinate2D) -> String {
            "\(Int((c.latitude * 2000).rounded())),\(Int((c.longitude * 2000).rounded()))"
        }
        return snap(a) + ">" + snap(b)
    }

    func leg(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> WalkLeg? { legs[Self.key(a, b)] }
    func path(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> [CLLocationCoordinate2D]? {
        paths[Self.key(a, b)]
    }

    /// Ask Apple for any of these walks we don't already have, one at a time.
    func fetch(_ pairs: [(CLLocationCoordinate2D, CLLocationCoordinate2D)]) async {
        for (a, b) in pairs {
            let k = Self.key(a, b)
            guard legs[k] == nil, !inFlight.contains(k), Date.now >= pausedUntil else { continue }
            inFlight.insert(k)
            defer { inFlight.remove(k) }
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: a))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: b))
            request.transportType = .walking
            do {
                guard let route = try await MKDirections(request: request).calculate().routes.first else { continue }
                var coords = [CLLocationCoordinate2D](repeating: .init(), count: route.polyline.pointCount)
                route.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: coords.count))
                legs[k] = WalkLeg(seconds: route.expectedTravelTime, meters: route.distance)
                paths[k] = coords
            } catch {
                // Offline or throttled: back off for a minute and let estimates stand.
                pausedUntil = .now.addingTimeInterval(60)
                return
            }
        }
    }
}
```

- [ ] **Step 3:** `xcodegen generate`, run tests, commit — `Fetch real walking times from Apple Maps`

**How the later tasks use it** (these amend the code shown in Tasks 4–7):

- **Task 4:** `MapScreen` owns `@State private var walks = WalkTimes()` and passes it through `SheetHost` to `TripView`.
- **Task 5, `TripView`:** takes `let walks: WalkTimes`. The plan becomes `store.planner.plan(from: origin, to: destination.coordinate, walks: walks.leg)`. A task asks Apple for the legs, and re-runs only when the shortlisted stops change:

```swift
    private var legsNeeded: [(CLLocationCoordinate2D, CLLocationCoordinate2D)] {
        var legs: [(CLLocationCoordinate2D, CLLocationCoordinate2D)] = []
        // No point asking Apple for a three-hour walk.
        if Walk.seconds(origin, destination.coordinate) <= 2 * TripPlanner.tooFarToWalk {
            legs.append((origin, destination.coordinate))
        }
        for o in store.planner.candidates(from: origin, to: destination.coordinate) {
            if let b = store.stop(o.boardStopId) { legs.append((origin, b.coordinate)) }
            if let a = store.stop(o.alightStopId) { legs.append((a.coordinate, destination.coordinate)) }
        }
        return legs
    }
    // on the List:
        .task(id: legsNeeded.map { WalkTimes.key($0.0, $0.1) }) { await walks.fetch(legsNeeded) }
```

  While `plan.isEstimate` is true, the big minute totals read "about 14 min" and a footnote says "Checking walking times with Apple Maps…". Once real, the "about" goes and the footnote reads "Walking times from Apple Maps." If Apple never answers, the footnote reads "Walking times are estimates right now." `Analytics.planned` waits for `!plan.isEstimate` (or 5 seconds, whichever comes first) so the event records the real answer.
- **Task 6, map:** `walkLegs` returns `walks.path(a, b) ?? [a, b]` for each leg, so the dotted line follows real streets once Apple has answered and is a straight line until then.
- **Task 7, Home:** favorite and recent rows keep estimates and say "about" ("Route A · about 14 min", "Walk about 9 min"). The nearest-stop walk time also stays an estimate.

### Task 4: Navigation and the Search screen

**Files:** Modify `RowViews.swift`, `SheetHost.swift`, `MapScreen.swift`, `Analytics.swift`. Create `ios/Bussin/Views/SearchView.swift`.

- [ ] **Step 1:** `Place` gains two cases:

```swift
enum Place: Hashable {
    case stop(String)
    case route(String)
    case bus(Int)
    case search
    case trip(Destination)
}
```

- [ ] **Step 2:** Fix every `switch` over `Place`:
  - `Analytics.viewed`: `case .search, .trip: break` (TripView sends its own events in Task 5).
  - `MapScreen.focusedRouteIds`: `case .search: return nil`; `case .trip: return tripSelection.map { [$0.routeId] } ?? []` (no shuttle chosen means every route dims).
  - `MapScreen.cameraForFocus`: `.search` returns `.region(Self.nyu)`; `.trip` is done in Task 6, return `.region(Self.nyu)` for now.
- [ ] **Step 3:** `MapScreen` owns `@State private var saved = SavedPlaces()` and `@State private var tripSelection: TripPlanner.Option?`, and passes both to `SheetHost` (`saved: saved, tripSelection: $tripSelection`).
- [ ] **Step 4:** `SheetHost` takes `let saved: SavedPlaces` and `@Binding var tripSelection: TripPlanner.Option?`, passes `saved` to `HomeView`, and adds destinations:

```swift
                    case .search: SearchView(saved: saved, path: $path)
                    case .trip(let d): TripView(store: store, saved: saved, destination: d,
                                                userCoordinate: userCoordinate, selection: $tripSelection)
```

  and opens the sheet fully for typing:

```swift
        .onChange(of: path) { _, new in
            if new.last == .search { detent = .large }
            else if case .trip = new.last { detent = Self.medium }
        }
```

- [ ] **Step 5:** `SearchView.swift`:

```swift
import SwiftUI
import MapKit

struct SearchView: View {
    let saved: SavedPlaces
    @Binding var path: [Place]
    @State private var search = PlaceSearch()
    @State private var resolving = false
    @State private var lookupFailed = false
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var search = search
        List {
            Section {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Address, building, or restaurant", text: $search.query)
                        .focused($focused)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                    if resolving { ProgressView() }
                }
            }
            if search.query.trimmingCharacters(in: .whitespaces).isEmpty {
                savedSection("Favorites", saved.favorites, icon: "star.fill")
                savedSection("Recent", saved.recents.filter { !saved.isFavorite($0) }, icon: "clock")
            } else if search.failed || lookupFailed {
                Text("Search isn't reachable right now. Check your connection and try again.")
                    .foregroundStyle(.secondary)
            } else {
                Section {
                    ForEach(search.suggestions, id: \.self) { s in
                        Button { Task { await pick(s) } } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(s.title).foregroundStyle(.primary)
                                if !s.subtitle.isEmpty {
                                    Text(s.subtitle).font(.footnote).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("Where to?")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { focused = true }
    }

    @ViewBuilder
    private func savedSection(_ title: String, _ places: [Destination], icon: String) -> some View {
        if !places.isEmpty {
            Section(title) {
                ForEach(places) { d in
                    Button { open(d) } label: { Label(d.name, systemImage: icon).foregroundStyle(.primary) }
                }
            }
        }
    }

    private func pick(_ s: MKLocalSearchCompletion) async {
        resolving = true
        defer { resolving = false }
        guard let d = await search.resolve(s) else { lookupFailed = true; return }
        lookupFailed = false
        open(d)
    }

    /// Replace the search screen with the answer, so Back goes home.
    private func open(_ d: Destination) {
        saved.noteSearched(d)
        path = [.trip(d)]
    }
}
```

- [ ] **Step 6:** Create a stub `TripView` that shows only the destination name so the build passes (Task 5 fills it in). `xcodegen generate`, build, run tests, commit — `Add the search screen`

### Task 5: Trip screen and analytics

**Files:** Replace `ios/Bussin/Views/TripView.swift`. Modify `Analytics.swift`.

- [ ] **Step 1:** In `Analytics`:

```swift
    /// What the planner answered. Records the route and stops, never the searched address.
    @MainActor
    static func planned(_ plan: TripPlanner.Plan, store: ShuttleStore) {
        if let o = plan.options.first {
            capture("trip_planned", [
                "route": store.route(for: o.routeId)?.letter ?? o.routeId,
                "board_stop": store.stop(o.boardStopId)?.name ?? o.boardStopId,
                "alight_stop": store.stop(o.alightStopId)?.name ?? o.alightStopId,
                "minutes": Int((o.total / 60).rounded()),
                "minutes_saved": Int(((plan.walkSeconds - o.total) / 60).rounded()),
            ])
        } else {
            capture("no_good_option", [
                "walk_minutes": Int((plan.walkSeconds / 60).rounded()),
                "too_far": plan.verdict == .tooFar,
            ])
        }
    }
```

- [ ] **Step 2:** `TripView.swift`:

```swift
import SwiftUI
import MapKit
import CoreLocation

struct TripView: View {
    let store: ShuttleStore
    let saved: SavedPlaces
    let destination: Destination
    let userCoordinate: CLLocationCoordinate2D?
    @Binding var selection: TripPlanner.Option?
    @State private var reported = false

    /// 715 Broadway stands in until location arrives (PRODUCT.md).
    static let hub = CLLocationCoordinate2D(latitude: 40.72927, longitude: -73.99394)
    private var origin: CLLocationCoordinate2D { userCoordinate ?? Self.hub }
    private var plan: TripPlanner.Plan { store.planner.plan(from: origin, to: destination.coordinate) }

    var body: some View {
        let plan = plan
        List {
            if userCoordinate == nil {
                Text("Location is off, so this starts from 715 Broadway.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if !plan.options.isEmpty {
                Section("Shuttle") {
                    ForEach(plan.options) { o in
                        Button { selection = o } label: { optionRow(o) }
                            .listRowBackground(selection?.id == o.id ? Color.blue.opacity(0.12) : nil)
                        if selection?.id == o.id { steps(o) }
                    }
                }
            }
            Section(plan.options.isEmpty ? "Best way there" : "Or") {
                if plan.verdict == .tooFar {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("The shuttles don't go near there").font(.headline)
                        Text("It's about \(Fmt.distance(plan.walkMeters)) away.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Button("Get directions in Apple Maps") { openInMaps() }
                } else {
                    Button { selection = nil } label: { walkRow(plan) }
                        .listRowBackground(selection == nil ? Color.blue.opacity(0.12) : nil)
                }
            }
            if !plan.idleRouteIds.isEmpty {
                Section {
                    Text(idleNote(plan.idleRouteIds.compactMap { store.route(for: $0)?.name }))
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle(destination.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { saved.toggleFavorite(destination) } label: {
                    Image(systemName: saved.isFavorite(destination) ? "star.fill" : "star")
                }
                .accessibilityLabel(saved.isFavorite(destination) ? "Remove favorite" : "Add favorite")
            }
        }
        // Keep the chosen route chosen as times refresh; fall back to the fastest.
        .onChange(of: plan.options, initial: true) { old, new in
            let hadShuttle = selection != nil || old.isEmpty
            selection = new.first { $0.id == selection?.id } ?? (hadShuttle ? new.first : nil)
            if !reported, store.feedState == .live {
                reported = true
                Analytics.planned(plan, store: store)
            }
        }
        .onDisappear { selection = nil }
    }

    private func optionRow(_ o: TripPlanner.Option) -> some View {
        HStack(spacing: 12) {
            if let r = store.route(for: o.routeId) { RouteBadge(letter: r.letter, colorHex: r.colorHex) }
            VStack(alignment: .leading, spacing: 2) {
                LiveLabel(text: "Bus in \(Fmt.eta(o.busArrives).lowercased())")
                Text("Arrive \(Fmt.clock(Date.now.addingTimeInterval(o.total)))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            Text(Fmt.minutes(o.total)).font(.title3.weight(.semibold)).foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func steps(_ o: TripPlanner.Option) -> some View {
        let board = store.stop(o.boardStopId)?.name ?? "the stop"
        let alight = store.stop(o.alightStopId)?.name ?? "your stop"
        let route = store.route(for: o.routeId)?.name ?? "the shuttle"
        Label("Walk \(Fmt.minutes(o.walkToStop)) to \(board)", systemImage: "figure.walk")
        Label("Ride \(route) \(o.stopCount) \(o.stopCount == 1 ? "stop" : "stops") to \(alight) · \(Fmt.minutes(o.ride))",
              systemImage: "bus.fill")
        Label("Walk \(Fmt.minutes(o.walkFromStop)) to \(destination.name)", systemImage: "figure.walk")
    }

    private func walkRow(_ plan: TripPlanner.Plan) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.walk").font(.title3).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text("Walk the whole way").foregroundStyle(.primary)
                Text("\(Fmt.distance(plan.walkMeters)) · arrive \(Fmt.clock(Date.now.addingTimeInterval(plan.walkSeconds)))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            Text(Fmt.minutes(plan.walkSeconds)).font(.title3.weight(.semibold)).foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }

    private func idleNote(_ names: [String]) -> String {
        names.count == 1
            ? "\(names[0]) also stops near here, but isn't running right now."
            : "\(names.joined(separator: ", ")) also stop near here, but aren't running right now."
    }

    private func openInMaps() {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: destination.coordinate))
        item.name = destination.name
        item.openInMaps()
    }
}
```

  Add to `Fmt`:

```swift
    /// "350 m" under a kilometre, else "1.2 km".
    static func distance(_ meters: Double) -> String {
        meters < 1000 ? "\(Int((meters / 10).rounded()) * 10) m" : String(format: "%.1f km", meters / 1000)
    }
```

- [ ] **Step 3:** Build, run tests, commit — `Add the trip screen: which shuttle, where to board, or just walk`

### Task 6: The trip on the map

**Files:** Modify `ios/Bussin/Views/MapScreen.swift`.

- [ ] **Step 1:** Inside `Map { }`, before `UserAnnotation()`:

```swift
            if case .trip(let d) = focus {
                let me = locationManager.location?.coordinate ?? TripView.hub
                ForEach(Array(walkLegs(me: me, to: d).enumerated()), id: \.offset) { _, leg in
                    MapPolyline(coordinates: leg)
                        .stroke(.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [0.1, 8]))
                }
                Marker(d.name, coordinate: d.coordinate).tint(.red)
            }
```

- [ ] **Step 2:** Helpers:

```swift
    /// Dotted walking lines: to the stop and from the stop, or straight there if walking.
    private func walkLegs(me: CLLocationCoordinate2D, to d: Destination) -> [[CLLocationCoordinate2D]] {
        guard let o = tripSelection,
              let board = store.stop(o.boardStopId), let alight = store.stop(o.alightStopId)
        else { return [[me, d.coordinate]] }
        return [[me, board.coordinate], [alight.coordinate, d.coordinate]]
    }
```

  `cameraForFocus` `.trip` case fits you, the destination, and both stops:

```swift
        case .trip(let d):
            var pts = [locationManager.location?.coordinate ?? TripView.hub, d.coordinate]
            if let o = tripSelection {
                pts += [o.boardStopId, o.alightStopId].compactMap { store.stop($0)?.coordinate }
            }
            return .region(regionAbovePanel(fitting: pts))
```

  and re-frame when the rider picks another option:

```swift
        .onChange(of: tripSelection?.id) { _, _ in
            guard case .trip = focus else { return }
            withAnimation(.easeInOut(duration: 0.5)) { camera = cameraForFocus() }
        }
```

- [ ] **Step 3:** Debug launch shortcuts in `openDebugLaunchPlace` (accept `-place search` with no colon too):

```swift
        if raw == "search" { path = [.search]; return }
        ...
        case "trip":    // -place trip:40.6943,-73.9865  (Tandon)
            let ll = parts[1].split(separator: ",").compactMap { Double($0) }
            if ll.count == 2 {
                path = [.trip(Destination(name: "Test destination", subtitle: "", latitude: ll[0], longitude: ll[1]))]
            }
```

- [ ] **Step 4:** Build, run tests, commit — `Draw the planned trip on the map`

### Task 7: Home — search bar, favorites, recents

**Files:** Modify `ios/Bussin/Views/HomeView.swift`.

- [ ] **Step 1:** `HomeView` takes `let saved: SavedPlaces`. At the top of the `List`:

```swift
            Section {
                NavigationLink(value: Place.search) {
                    Label("Where to?", systemImage: "magnifyingglass").foregroundStyle(.secondary)
                }
            }
            if !saved.favorites.isEmpty {
                Section("Favorites") {
                    ForEach(saved.favorites) { placeRow($0, icon: "star.fill", tint: .yellow) }
                }
            }
            if !saved.homeRecents.isEmpty {
                Section("Recent") {
                    ForEach(saved.homeRecents) { placeRow($0, icon: "clock", tint: .secondary) }
                }
            }
```

  and the row, with the live one-line answer the prototype shows:

```swift
    private func placeRow(_ d: Destination, icon: String, tint: Color) -> some View {
        NavigationLink(value: Place.trip(d)) {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(tint).frame(width: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(d.name)
                    Text(summary(for: d)).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func summary(for d: Destination) -> String {
        let plan = store.planner.plan(from: userCoordinate ?? TripView.hub, to: d.coordinate)
        if let o = plan.options.first, let r = store.route(for: o.routeId) {
            return "\(r.name) · \(Fmt.minutes(o.total))"
        }
        return plan.verdict == .tooFar ? "No shuttle goes there" : "Walk \(Fmt.minutes(plan.walkSeconds))"
    }
```

  Replace `HomeView.hub` with `TripView.hub` so there is one definition.

- [ ] **Step 2:** Build, run tests, commit — `Put search, favorites, and recent places on the home screen`

### Task 8: Check it for real

- [ ] Full test run: every test passes (21 existing + 15 new).
- [ ] Walking times: pick a trip, compare the app's "Walk the whole way" minutes with Apple Maps walking directions for the same two points. They should match to the minute. Turn on Airplane Mode in the simulator's host (or block the network) and confirm the estimate fallback and its footnote.
- [ ] Simulator, with screenshots saved to the scratchpad and looked at:
  - `-place search`: type "Tandon", pick the result, land on a trip with a shuttle option (weekday daytime) or the idle-route note (off hours).
  - `-place trip:40.6943,-73.9865`: red pin in Brooklyn, dotted walk lines, chosen route bright and others dimmed.
  - A place two blocks away: "Walk the whole way" selected, no shuttle section.
  - "JFK Airport": the too-far message and the Apple Maps button.
  - Star a place, go Home: it appears under Favorites with a live summary; relaunch and it is still there.
  - Light and dark mode.
- [ ] Record what could not be checked (for example, shuttle options at night when no buses run).

### Task 9: Phone, docs, and wrap-up

- [ ] **Signing.** Add `DEVELOPMENT_TEAM =` to `ios/Config.xcconfig` and `DEVELOPMENT_TEAM: $(DEVELOPMENT_TEAM)` plus `CODE_SIGN_STYLE: Automatic` to the Bussin target in `project.yml`. Chris's real team ID goes in the gitignored `ios/Secrets.xcconfig`.
- [ ] **Chris, on the Mac and phone** (a free Apple ID works; the app then needs reinstalling every 7 days until the Developer Program enrolment goes through):
  1. Xcode → Settings → Accounts → add Apple ID.
  2. Plug in the iPhone, tap Trust, and turn on Settings → Privacy & Security → Developer Mode.
  3. In Xcode pick the iPhone as the run destination and press Run.
  4. On the phone: Settings → General → VPN & Device Management → trust the developer certificate.
- [ ] Update the spec's Search line (Apple search now, curated list dropped) and the Phase 3 row.
- [ ] Update `CLAUDE.md` "Where things stand" and "What's next".
- [ ] Update `build-map.html` (Phase 3 steps done, plain wording, model tags) and republish to the same artifact URL.
- [ ] Log the build in `docs/index.html` if a class build is due.
- [ ] Finish the branch with superpowers:finishing-a-development-branch.

## Known limits after this phase

- Trip-screen walking times are real Apple Maps routes. Two places still use straight-line estimates, both marked "about": the one-line summaries on Home, and the first second of a trip before Apple answers.
- The planner picks which stops to use with estimates, then times that choice with Apple. Very occasionally a different stop pair would have been a minute faster on real streets.
- No transfers between shuttle routes.
- The planner trusts live buses only. It knows nothing about schedules, so at 2 a.m. it says walk.
- Apple search needs a connection. Offline, favorites and recents still open.
