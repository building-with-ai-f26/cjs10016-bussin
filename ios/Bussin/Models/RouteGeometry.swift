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
