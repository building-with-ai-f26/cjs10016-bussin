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
                    var forward = (proj.distanceAlong - m.distance).truncatingRemainder(dividingBy: g.length)
                    if forward < 0 { forward += g.length }
                    let instant = forward / dt
                    if instant < 15 {       // a jump beyond 15 m/s is noise, not driving
                        speed = max(1.5, min(9, 0.7 * m.speed + 0.3 * instant))
                    } else {
                        speed = m.speed
                    }
                } else {
                    speed = m.speed
                }
            }
            memory[bus.id] = Memory(distance: proj.distanceAlong, time: now, speed: speed)
            out.append(TrackedBus(bus: bus, distanceAlong: proj.distanceAlong, speed: speed))
        }
        return out.sorted { $0.id < $1.id }
    }
}
