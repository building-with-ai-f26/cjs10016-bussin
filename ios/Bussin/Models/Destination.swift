import Foundation
import CoreLocation

/// Somewhere a rider searched for. Small and Codable so it can be saved as a favorite.
struct Destination: Hashable, Codable, Identifiable {
    let name: String
    let subtitle: String
    let latitude: Double
    let longitude: Double

    var id: String { "\(name)|\(latitude)|\(longitude)" }
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
}
