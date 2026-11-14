import CoreLocation
import Observation

/// Tells SwiftUI when the rider answers (or later changes) the location permission.
/// CLLocationManager's own status isn't observable, so without this Home wouldn't
/// notice "Don't Allow" until the app was reopened.
@Observable @MainActor
final class LocationAccess: NSObject, CLLocationManagerDelegate {
    let manager = CLLocationManager()
    private(set) var status: CLAuthorizationStatus

    override init() {
        status = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    /// True once the rider has said no, or the phone restricts it. Not true before they've been asked.
    var isDenied: Bool { status == .denied || status == .restricted }
    var coordinate: CLLocationCoordinate2D? { manager.location?.coordinate }

    func start() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let new = manager.authorizationStatus
        Task { @MainActor in self.status = new }
    }
}
