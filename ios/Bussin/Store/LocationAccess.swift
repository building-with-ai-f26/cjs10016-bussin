import CoreLocation
import Observation

/// Tells SwiftUI when the rider answers (or later changes) the location permission.
/// CLLocationManager's own status isn't observable, so without this Home wouldn't
/// notice "Don't Allow" until the app was reopened.
@Observable @MainActor
final class LocationAccess: NSObject, CLLocationManagerDelegate {
    let manager = CLLocationManager()
    private(set) var status: CLAuthorizationStatus
    /// Which way the phone is facing, in degrees from north. Only read during a Go trip.
    private(set) var heading: Double?

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

    /// Go: keep following the rider with the screen off, for this trip only. iOS shows a small
    /// blue location pill while this is on. The permission stays "While Using the App".
    private var tripSession: CLBackgroundActivitySession?

    func beginTripTracking() {
        guard tripSession == nil, status == .authorizedWhenInUse || status == .authorizedAlways else { return }
        tripSession = CLBackgroundActivitySession()
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.startUpdatingLocation()
        manager.headingFilter = 5
        manager.startUpdatingHeading()
    }

    func endTripTracking() {
        tripSession?.invalidate()
        tripSession = nil
        manager.allowsBackgroundLocationUpdates = false
        manager.stopUpdatingHeading()
        heading = nil
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // No reading when the compass needs calibrating; true north when iOS knows it.
        let h: Double? = newHeading.headingAccuracy < 0 ? nil
            : (newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading)
        Task { @MainActor in self.heading = h }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let new = manager.authorizationStatus
        Task { @MainActor in self.status = new }
    }
}
