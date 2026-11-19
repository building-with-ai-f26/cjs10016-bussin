import Foundation
import CoreLocation

/// A live bus enriched with everything the ETA math needs.
struct TrackedBus: Identifiable {
    let bus: LiveBus
    let distanceAlong: Double   // meters along its route
    let speed: Double           // m/s, learned from movement between pings
    /// Which way the bus is going, degrees clockwise from north: the way its route runs where it is.
    /// Nil while that's unclear (a street the route uses both ways, and the bus hasn't moved yet).
    var heading: Double? = nil
    var id: Int { bus.id }
}

/// Keeps short per-bus history so speed can be learned. Value type on purpose:
/// the store owns one and mutates it on each poll.
struct BusTracker {
    static let defaultSpeed = 4.0          // ~9 mph incl. stops, same as the prototype
    static let maxOffsetMeters = 300.0     // beyond this, the ping is a glitch
    /// Speed is averaged over roughly this many seconds of driving, so a red light
    /// or a stop dwell doesn't swing every downstream ETA (bug seen live Nov 11).
    static let memorySeconds = 120.0

    static let movedMeters = 15.0          // GPS drift is a few meters; real driving is more than this

    private struct Memory {
        var distance: Double
        var time: Date
        var speed: Double
        var sure: Bool                     // the side of the route is known (one-way here, or seen moving)
        var anchor: CLLocationCoordinate2D // where the bus was when its movement was last measured
    }
    private var memory: [Int: Memory] = [:]

    mutating func update(buses: [LiveBus], geometries: [String: RouteGeometry], at now: Date) -> [TrackedBus] {
        var out: [TrackedBus] = []
        for bus in buses {
            guard let g = geometries[bus.routeId] else { continue }
            let candidates = g.projections(bus.coordinate).filter { $0.offsetMeters <= Self.maxOffsetMeters }
            guard let nearest = candidates.first else {
                memory[bus.id] = nil        // forget glitching buses; they restart fresh
                continue
            }
            let prior = memory[bus.id]
            let moved = prior.map { Walk.meters($0.anchor, bus.coordinate) / Walk.detour } ?? 0
            var proj = nearest
            var sure = candidates.count == 1
            var anchor = prior?.anchor ?? bus.coordinate
            if candidates.count > 1 {
                if let prior, moved >= Self.movedMeters {
                    // It moved: it's on the side of the street whose direction matches that movement.
                    let way = RouteGeometry.bearing(prior.anchor, bus.coordinate)
                    proj = candidates.min { gap(g.direction(at: $0.distanceAlong), way) < gap(g.direction(at: $1.distanceAlong), way) }!
                    sure = true
                } else if let prior {
                    // Parked or drifting: stay on the side it was on.
                    proj = candidates.min { g.along($0.distanceAlong, prior.distance) < g.along($1.distanceAlong, prior.distance) }!
                    sure = prior.sure
                }
            }
            if moved >= Self.movedMeters || prior == nil { anchor = bus.coordinate }
            var speed = Self.defaultSpeed
            if let m = memory[bus.id] {
                let dt = now.timeIntervalSince(m.time)
                if dt >= 1, dt <= 90 {
                    var forward = (proj.distanceAlong - m.distance).truncatingRemainder(dividingBy: g.length)
                    if forward < 0 { forward += g.length }
                    let instant = forward / dt
                    if instant < 15 {       // a jump beyond 15 m/s is noise, not driving
                        let weight = dt / (dt + Self.memorySeconds)   // 4 s poll → ~3%
                        speed = max(1.5, min(9, (1 - weight) * m.speed + weight * instant))
                    } else {
                        speed = m.speed
                    }
                } else {
                    speed = m.speed
                }
            }
            memory[bus.id] = Memory(distance: proj.distanceAlong, time: now, speed: speed, sure: sure, anchor: anchor)
            out.append(TrackedBus(bus: bus, distanceAlong: proj.distanceAlong, speed: speed,
                                  heading: sure ? g.direction(at: proj.distanceAlong) : nil))
        }
        return out.sorted { $0.id < $1.id }
    }

    /// Degrees between two compass directions, 0...180.
    private func gap(_ a: Double, _ b: Double) -> Double {
        abs((a - b + 540).truncatingRemainder(dividingBy: 360) - 180)
    }
}
