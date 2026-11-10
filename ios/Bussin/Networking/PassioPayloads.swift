import Foundation
import CoreLocation

/// Raw shapes of passio3.com/www/mapGetData.php responses.
/// The feed is PHP: empty collections may arrive as `[]` instead of `{}`,
/// numbers may arrive as strings, and some values are null. Every decode
/// here tolerates that rather than throwing the whole payload away.

struct PassioStopsPayload: Decodable {
    var stops: [String: PassioStop] = [:]            // keyed "ID<stopId>"
    var routes: [String: PassioRouteEntry] = [:]     // keyed by routeId
    var routePoints: [String: [[PassioPoint]]] = [:] // routeId -> segments -> points
    var routeShortNames: [String: String] = [:]      // routeId -> letter ("A"); nulls dropped
    var excludedRoutesID: [Int] = []                 // routes Passio has suspended right now

    private enum CodingKeys: String, CodingKey {
        case stops, routes, routePoints, routeShortNames, excludedRoutesID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stops = (try? c.decode([String: PassioStop].self, forKey: .stops)) ?? [:]
        routes = (try? c.decode([String: PassioRouteEntry].self, forKey: .routes)) ?? [:]
        routePoints = (try? c.decode([String: [[PassioPoint]]].self, forKey: .routePoints)) ?? [:]
        let names = (try? c.decode([String: String?].self, forKey: .routeShortNames)) ?? [:]
        routeShortNames = names.compactMapValues { $0 }
        excludedRoutesID = (try? c.decode([Int].self, forKey: .excludedRoutesID)) ?? []
    }
}

struct PassioStop: Decodable {
    let stopId: String
    let name: String
    let latitude: Double
    let longitude: Double
}

struct PassioPoint: Decodable {
    let lat: String
    let lng: String
    var coordinate: CLLocationCoordinate2D {
        .init(latitude: Double(lat) ?? 0, longitude: Double(lng) ?? 0)
    }
}

/// Feed shape: ["Route A", "#f7b6d2", ["1", "6545", 0], ["2", "6574", 0], ...]
struct PassioRouteEntry: Decodable {
    let name: String
    let color: String
    let stopIds: [String]

    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        name = try c.decode(String.self)
        color = try c.decode(String.self)
        var ids: [String] = []
        while !c.isAtEnd {
            if let ref = try? c.decode(PassioStopRef.self) {
                ids.append(ref.stopId)
            } else if (try? c.decode(String.self)) != nil || (try? c.decode(Double.self)) != nil {
                continue  // consumed an unexpected scalar; move on
            } else {
                break     // unknown shape — stop rather than loop forever
            }
        }
        stopIds = ids
    }
}

struct PassioStopRef: Decodable {
    let stopId: String
    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        _ = try c.decode(String.self)        // position ("1", "2", ...)
        stopId = try c.decode(String.self)   // the stop id
    }
}

struct PassioBusesPayload: Decodable {
    var buses: [String: [PassioBus]] = [:]

    private enum CodingKeys: String, CodingKey { case buses }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        buses = (try? c.decode([String: [PassioBus]].self, forKey: .buses)) ?? [:]
    }
}

struct PassioBus: Decodable {
    let deviceId: Int
    let bus: String?
    let latitude: String
    let longitude: String
    let calculatedCourse: String?
    let paxLoad: Int?
    let totalCap: Int?
    let outOfService: Int?
    let outdated: Int?
    let routeId: String?
}
