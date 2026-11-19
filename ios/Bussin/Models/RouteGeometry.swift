import Foundation
import CoreLocation
import simd

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

    let originLat: Double
    let originLon: Double
    let mPerDegLon: Double
    static let mPerDegLat = 111_132.0

    struct Projection {
        let distanceAlong: Double   // meters from the route's start
        let offsetMeters: Double    // perpendicular distance off the line
    }

    static func build(route: ShuttleRoute, stops: [String: ShuttleStop]) -> RouteGeometry? {
        guard route.coordinates.count >= 2 else { return nil }
        let o = route.coordinates[0]
        let mLon = 111_320.0 * cos(o.latitude * .pi / 180)
        func plane(_ c: CLLocationCoordinate2D) -> SIMD2<Double> {
            SIMD2((c.longitude - o.longitude) * mLon, (c.latitude - o.latitude) * mPerDegLat)
        }
        let pts = route.coordinates.map(plane)
        var cum = [0.0]
        for i in 1..<pts.count { cum.append(cum[i - 1] + simd_distance(pts[i - 1], pts[i])) }
        let length = cum[cum.count - 1]
        guard length > 0 else { return nil }
        let isLoop = route.stopIds.count >= 2 && route.stopIds.first == route.stopIds.last

        // Assign each stop a distance along the line, in boarding order. Same scoring
        // as the prototype's build script: prefer the nearest segment, lightly penalize
        // jumping far ahead, and never go backwards past the previous stop.
        var assigned: [(stopId: String, distance: Double)] = []
        var prev = -1.0
        let ids = route.stopIds
        for (k, sid) in ids.enumerated() {
            guard let stop = stops[sid] else { continue }
            if k == ids.count - 1 && isLoop {
                assigned.append((sid, length))
                break
            }
            let p = plane(stop.coordinate)
            var best: (score: Double, d: Double)? = nil
            for i in 1..<pts.count {
                if cum[i] < prev { continue }
                let a = pts[i - 1], b = pts[i]
                let seg = cum[i] - cum[i - 1]
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

        return RouteGeometry(routeId: route.id, points: pts, cumulative: cum, length: length,
                             isLoop: isLoop, stopDistances: assigned,
                             originLat: o.latitude, originLon: o.longitude, mPerDegLon: mLon)
    }

    /// Nearest point on the whole line. Used for live buses every poll.
    func project(_ c: CLLocationCoordinate2D) -> Projection {
        let p = SIMD2((c.longitude - originLon) * mPerDegLon, (c.latitude - originLat) * Self.mPerDegLat)
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

    /// Every place on the line a point could belong to, nearest first. Where a route runs up a
    /// street and back down it, a bus between the two lanes matches both, and only its movement
    /// says which one it's on. Matches within `slack` meters of the nearest count; matches closer
    /// than 150 m along the line are the same place.
    func projections(_ c: CLLocationCoordinate2D, slack: Double = 30) -> [Projection] {
        let p = SIMD2((c.longitude - originLon) * mPerDegLon, (c.latitude - originLat) * Self.mPerDegLat)
        var all: [Projection] = []
        for i in 1..<points.count {
            let a = points[i - 1], b = points[i]
            let seg = cumulative[i] - cumulative[i - 1]
            let t = seg == 0 ? 0 : max(0, min(1, simd_dot(p - a, b - a) / (seg * seg)))
            all.append(Projection(distanceAlong: cumulative[i - 1] + seg * t, offsetMeters: simd_distance(p, a + (b - a) * t)))
        }
        all.sort { $0.offsetMeters < $1.offsetMeters }
        guard let best = all.first else { return [] }
        var kept: [Projection] = []
        for q in all where q.offsetMeters <= best.offsetMeters + slack {
            if !kept.contains(where: { along($0.distanceAlong, q.distanceAlong) < 150 }) { kept.append(q) }
        }
        return kept
    }

    /// Meters between two places on the line, going whichever way is shorter on a loop.
    func along(_ a: Double, _ b: Double) -> Double {
        let d = abs(a - b)
        return isLoop ? min(d, length - d) : d
    }

    /// Which way the route runs at a distance along it, in degrees clockwise from north.
    /// Measured across 20 m, so tiny kinks in the drawn line don't twist the arrow.
    func direction(at distance: Double) -> Double {
        let from = isLoop ? wrapped(distance - 10) : max(0, min(length - 20, distance - 10))
        let to = isLoop ? wrapped(from + 20) : min(length, from + 20)
        return Self.bearing(pointCoordinate(at: from), pointCoordinate(at: to))
    }

    /// Compass bearing from a to b, degrees clockwise from north.
    static func bearing(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let dx = (b.longitude - a.longitude) * cos(a.latitude * .pi / 180)
        let dy = b.latitude - a.latitude
        let deg = atan2(dx, dy) * 180 / .pi
        return deg < 0 ? deg + 360 : deg
    }

    /// The stretch of line that starts `start` meters along and runs `meters` forward, as map
    /// points: the part of a route a rider actually rides. On a loop it wraps through the start;
    /// a one-way line stops at its end. Always at least two points, so it can be drawn.
    func coordinates(from start: Double, along meters: Double) -> [CLLocationCoordinate2D] {
        let s = isLoop ? wrapped(start) : max(0, min(length, start))
        let span = max(0, isLoop ? min(meters, length) : min(meters, length - s))
        var out = [pointCoordinate(at: s)]
        // Every bend of the line passed on the way, in order. A loop may pass its start once.
        for lap in 0...(isLoop ? 1 : 0) {
            for (i, d) in cumulative.enumerated() {
                let along = d + Double(lap) * length
                if along > s && along < s + span { out.append(coordinate(of: points[i])) }
            }
        }
        out.append(pointCoordinate(at: isLoop ? wrapped(s + span) : s + span))
        return out
    }

    /// Distance folded back onto the loop, 0 ..< length.
    private func wrapped(_ d: Double) -> Double {
        let r = d.truncatingRemainder(dividingBy: length)
        return r < 0 ? r + length : r
    }

    private func coordinate(of q: SIMD2<Double>) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: originLat + q.y / Self.mPerDegLat,
                               longitude: originLon + q.x / mPerDegLon)
    }

    /// Coordinate at a given distance along the line (tests + "bus is here" UI).
    func pointCoordinate(at distance: Double) -> CLLocationCoordinate2D {
        let d = max(0, min(length, distance))
        var i = 1
        while i < cumulative.count - 1 && cumulative[i] < d { i += 1 }
        let seg = cumulative[i] - cumulative[i - 1]
        let t = seg == 0 ? 0 : (d - cumulative[i - 1]) / seg
        let q = points[i - 1] + (points[i] - points[i - 1]) * t
        return CLLocationCoordinate2D(latitude: originLat + q.y / Self.mPerDegLat,
                                      longitude: originLon + q.x / mPerDegLon)
    }
}
