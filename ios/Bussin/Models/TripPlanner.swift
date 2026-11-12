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
