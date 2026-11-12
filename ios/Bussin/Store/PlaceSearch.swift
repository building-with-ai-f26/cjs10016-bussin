import Foundation
import MapKit
import Observation

/// Type-ahead suggestions from Apple Maps, biased to where the shuttles run.
@Observable @MainActor
final class PlaceSearch: NSObject, MKLocalSearchCompleterDelegate {
    private(set) var suggestions: [MKLocalSearchCompletion] = []
    private(set) var failed = false
    var query = "" {
        didSet {
            let q = query.trimmingCharacters(in: .whitespaces)
            if q.isEmpty { suggestions = []; failed = false } else { completer.queryFragment = q }
        }
    }

    /// Washington Square to MetroTech to Langone, with room around it.
    static let serviceArea = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.722, longitude: -73.985),
        span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.10))

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.region = Self.serviceArea
        completer.resultTypes = [.address, .pointOfInterest]
    }

    /// Turn a tapped suggestion into a place with a coordinate.
    func resolve(_ completion: MKLocalSearchCompletion) async -> Destination? {
        let request = MKLocalSearch.Request(completion: completion)
        request.region = Self.serviceArea
        guard let item = try? await MKLocalSearch(request: request).start().mapItems.first else { return nil }
        let c = item.placemark.coordinate
        return Destination(name: item.name ?? completion.title, subtitle: completion.subtitle,
                           latitude: c.latitude, longitude: c.longitude)
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in self.suggestions = results; self.failed = false }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in self.suggestions = []; self.failed = true }
    }
}
