import Foundation
import CoreLocation

struct ShuttleRoute: Identifiable {
    let id: String                              // Passio routeId, e.g. "74769"
    let name: String                            // "Route A"
    let letter: String                          // "A"
    let colorHex: String                        // "#f7b6d2"
    let coordinates: [CLLocationCoordinate2D]   // full polyline, segments flattened in order
    let stopIds: [String]                       // boarding order; loops repeat the first stop last
}

struct ShuttleStop: Identifiable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let routeIds: [String]
}

enum ShuttleLetters {
    static let allowed: Set<String> = ["A", "B", "C", "E", "F", "G", "W"]
}

struct ShuttleCatalog {
    let routes: [ShuttleRoute]
    let stops: [ShuttleStop]
    let excludedRouteIds: Set<String>

    static func from(payload: PassioStopsPayload) -> ShuttleCatalog {
        var routes: [ShuttleRoute] = []
        var stopRouteIds: [String: [String]] = [:]

        for (rid, entry) in payload.routes {
            guard let letter = payload.routeShortNames[rid],
                  ShuttleLetters.allowed.contains(letter) else { continue }
            let pts = (payload.routePoints[rid] ?? []).flatMap { $0 }.map(\.coordinate)
            guard !pts.isEmpty else { continue }
            routes.append(ShuttleRoute(id: rid, name: entry.name, letter: letter,
                                       colorHex: entry.color, coordinates: pts,
                                       stopIds: entry.stopIds))
            for sid in Set(entry.stopIds) {
                stopRouteIds[sid, default: []].append(rid)
            }
        }
        routes.sort { $0.letter < $1.letter }

        var stops: [ShuttleStop] = []
        for (sid, rids) in stopRouteIds {
            guard let raw = payload.stops["ID" + sid] else { continue }
            stops.append(ShuttleStop(id: sid, name: raw.name,
                                     coordinate: .init(latitude: raw.latitude, longitude: raw.longitude),
                                     routeIds: rids.sorted()))
        }
        stops.sort { $0.name < $1.name }

        return ShuttleCatalog(routes: routes, stops: stops,
                              excludedRouteIds: Set(payload.excludedRoutesID.map(String.init)))
    }
}
