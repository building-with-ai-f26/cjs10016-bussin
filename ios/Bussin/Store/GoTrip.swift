import Foundation
import CoreLocation
import Observation
import UIKit

/// The Go trip that's running, if any. Feeds `TripSession` your location and the live buses
/// every couple of seconds, buzzes when it's time to get off, and words each step for the screen.
@Observable @MainActor
final class GoTrip {
    private(set) var session: TripSession?
    private(set) var destination: Destination?
    private(set) var lastLocation: CLLocationCoordinate2D?
    /// Changes whenever a new location arrives, so the map can follow.
    var lastLocationKey: String { lastLocation.map { "\($0.latitude),\($0.longitude)" } ?? "" }

    static let tickSeconds = 2.0

    var isRunning: Bool { session != nil }

    /// Starts following `option`. Returns false if the route or its stops aren't known.
    @discardableResult
    func start(option: TripPlanner.Option, to destination: Destination,
               store: ShuttleStore, me: CLLocationCoordinate2D?) -> Bool {
        guard let g = store.geometries[option.routeId],
              let s = TripSession(option: option, destination: destination.coordinate,
                                  geometry: g, stops: store.stopsById, now: .now) else { return false }
        session = s
        self.destination = destination
        Analytics.capture("trip_started", ["route": store.route(for: option.routeId)?.letter ?? ""])
        tick(store: store, me: me)
        return true
    }

    /// Stops the trip. `outcome` is "arrived", "ended_early", or "timed_out" (no places, ever).
    func end(outcome: String? = nil) {
        guard let s = session else { return }
        let result = outcome ?? (s.step == .arrived ? "arrived" : s.step == .timedOut ? "timed_out" : "ended_early")
        Analytics.capture("trip_ended", ["outcome": result,
                                         "minutes": Int(Date.now.timeIntervalSince(s.startedAt) / 60)])
        session = nil
        destination = nil
    }

    /// Runs for the life of the map screen; does nothing while no trip is running.
    func run(store: ShuttleStore, location: LocationAccess) async {
        while !Task.isCancelled {
            if session != nil { tick(store: store, me: location.coordinate) }
            try? await Task.sleep(for: .seconds(Self.tickSeconds))
        }
    }

    func tick(store: ShuttleStore, me: CLLocationCoordinate2D?) {
        guard var s = session else { return }
        if let me { lastLocation = me }
        let events = s.update(me: me ?? lastLocation, buses: store.trackedBuses, now: .now)
        session = s
        for e in events {
            switch e {
            case .getOffNext: UINotificationFeedbackGenerator().notificationOccurred(.warning)
            case .arrived: UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .switchedBus, .gotOff, .timedOut: break
            }
        }
    }

    // MARK: - Words for each step

    struct Status: Equatable {
        let title: String
        let detail: String
    }

    func status(store: ShuttleStore) -> Status? {
        guard let s = session else { return nil }
        let board = store.stop(s.option.boardStopId)?.name ?? "your stop"
        let alight = store.stop(s.option.alightStopId)?.name ?? "your stop"
        let route = store.route(for: s.option.routeId)?.name ?? "the shuttle"
        let bus = s.busId.flatMap { id in store.trackedBuses.first { $0.id == id }?.bus.number }
        let place = destination?.name ?? "your destination"
        let busName = bus.map { "Bus \($0)" } ?? "The next \(route) bus"

        switch s.step {
        case .toStop:
            let when = s.busSecondsAway.map { $0 < 45 ? "is at the stop" : "arrives in \(Fmt.minutes($0))" }
            return Status(title: "Walk to \(board)", detail: when.map { "\(busName) \($0)" } ?? "Waiting for a \(route) bus")
        case .atStop:
            let when = s.busSecondsAway.map { $0 < 45 ? "is here" : "arrives in \(Fmt.minutes($0))" }
            return Status(title: "Wait at \(board)", detail: when.map { "\(busName) \($0)" } ?? "Waiting for a \(route) bus")
        case .riding:
            let left = s.stopsLeft
            let time = s.rideSecondsLeft.map { " · about \(Fmt.minutes($0))" } ?? ""
            return Status(title: "\(left) \(left == 1 ? "stop" : "stops") left", detail: "Get off at \(alight)\(time)")
        case .getOffNext:
            return Status(title: "Get off at the next stop", detail: alight)
        case .toDestination:
            let walk = lastLocation.map { " · about \(Fmt.minutes(Walk.seconds($0, s.destination)))" } ?? ""
            return Status(title: "Walk to \(place)", detail: "You're off the bus\(walk)")
        case .arrived:
            return Status(title: "You're here", detail: place)
        case .timedOut:
            return Status(title: "Trip ended", detail: "Go stops following a trip after two hours.")
        }
    }
}
