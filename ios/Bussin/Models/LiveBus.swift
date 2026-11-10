import Foundation
import CoreLocation

struct LiveBus: Identifiable {
    let id: Int                     // Passio deviceId — stable per physical bus
    let number: String              // painted fleet number, e.g. "2146"
    let routeId: String
    let coordinate: CLLocationCoordinate2D
    let headingDegrees: Double?     // 0 = north
    let ridersAboard: Int?          // paxLoad
    let capacity: Int?              // totalCap
    let isStale: Bool               // Passio's own outdated flag

    static func from(payload: PassioBusesPayload, allowedRouteIds: Set<String>) -> [LiveBus] {
        payload.buses.values.flatMap { $0 }.compactMap { raw in
            guard let rid = raw.routeId, allowedRouteIds.contains(rid),
                  raw.outOfService != 1,
                  let lat = Double(raw.latitude), let lng = Double(raw.longitude)
            else { return nil }
            return LiveBus(id: raw.deviceId,
                           number: raw.bus ?? String(raw.deviceId),
                           routeId: rid,
                           coordinate: .init(latitude: lat, longitude: lng),
                           headingDegrees: raw.calculatedCourse.flatMap(Double.init),
                           ridersAboard: raw.paxLoad,
                           capacity: raw.totalCap,
                           isStale: raw.outdated == 1)
        }
        .sorted { $0.id < $1.id }
    }
}
