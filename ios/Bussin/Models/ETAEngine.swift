import Foundation

/// Pure arrival math over geometries + tracked buses. Rebuilt cheaply every poll.
struct ETAEngine {
    let geometries: [String: RouteGeometry]
    let buses: [TrackedBus]

    struct Departure: Identifiable {
        let routeId: String
        let next: Double?           // seconds to the next bus, nil if none coming
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
        // A loop lists its first stop twice (start and end): use the first entry.
        guard let sd = g.stopDistances.first(where: { $0.stopId == stopId }) else { return [] }
        var times = rbuses.map { forwardGap(from: $0.distanceAlong, to: sd.distance, length: g.length) / $0.speed }
        // If more are wanted than buses exist, later laps follow one full loop apart.
        if g.isLoop {
            var lap = 1
            while times.count < count && lap <= 3 {
                times.append(contentsOf: rbuses.map {
                    forwardGap(from: $0.distanceAlong, to: sd.distance, length: g.length) / $0.speed
                        + Double(lap) * g.length / $0.speed
                })
                lap += 1
            }
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
        let list = g.isLoop ? Array(g.stopDistances.dropLast()) : g.stopDistances
        var seen = Set<String>()
        return list.compactMap { sd -> UpcomingStop? in
            guard seen.insert(sd.stopId).inserted else { return nil }
            return UpcomingStop(stopId: sd.stopId,
                                secondsAway: forwardGap(from: b.distanceAlong, to: sd.distance, length: g.length) / b.speed)
        }
        .sorted { $0.secondsAway < $1.secondsAway }
    }
}
