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
