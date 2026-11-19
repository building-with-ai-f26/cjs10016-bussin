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
    /// Where you were when you tapped Go. The trip screen asked Apple Maps for the walk from here,
    /// so the dotted line on the map can follow real streets.
    private(set) var startLocation: CLLocationCoordinate2D?
    /// Changes whenever a new location arrives, so the map can follow.
    var lastLocationKey: String { lastLocation.map { "\($0.latitude),\($0.longitude)" } ?? "" }

    static let tickSeconds = 2.0

    private let card = GoLiveCard()
    #if DEBUG
    private var debugHoldingAlert = false
    #endif
    private weak var location: LocationAccess?

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
        startLocation = me
        Analytics.capture("trip_started", ["route": store.route(for: option.routeId)?.letter ?? ""])
        location?.beginTripTracking()
        card.askForNotifications()
        let route = store.route(for: option.routeId)
        card.start(GoActivityAttributes(routeLetter: route?.letter ?? "?", routeColorHex: route?.colorHex ?? "#8E8E93",
                                        destinationName: destination.name),
                   Self.liveState(s, status(store: store)))
        tick(store: store, me: me)
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "goAlertTest") { debugAlertSoon(store: store) }
        #endif
        return true
    }

    /// Stops the trip. `outcome` is "arrived", "ended_early", or "timed_out" (no places, ever).
    func end(outcome: String? = nil) {
        guard let s = session else { return }
        let result = outcome ?? (s.step == .arrived ? "arrived" : s.step == .timedOut ? "timed_out" : "ended_early")
        Analytics.capture("trip_ended", ["outcome": result,
                                         "minutes": Int(Date.now.timeIntervalSince(s.startedAt) / 60)])
        card.end(nil)
        location?.endTripTracking()
        #if DEBUG
        debugHoldingAlert = false
        #endif
        session = nil
        destination = nil
        startLocation = nil
    }

    /// Runs for the life of the map screen; does nothing while no trip is running.
    func run(store: ShuttleStore, location: LocationAccess) async {
        self.location = location
        GoLiveCard.endLeftovers()
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

        // The lock screen card: redraw on change, and light the screen with a buzz at "get off next".
        #if DEBUG
        if debugHoldingAlert { return }
        #endif
        guard let words = status(store: store) else { return }
        let state = Self.liveState(s, words)
        if s.isOver {
            card.end(state, after: s.step == .arrived ? 5 * 60 : 0)
            location?.endTripTracking()
        } else if events.contains(.getOffNext) {
            card.update(state, alert: (words.title, words.detail))
        } else {
            card.update(state)
        }
    }

    #if DEBUG
    /// `-goAlertTest YES`: 8 seconds after Go, act as if the bus just passed the stop before yours,
    /// so the lock screen alert and buzz can be checked without riding a real shuttle.
    private func debugAlertSoon(store: ShuttleStore) {
        Task {
            try? await Task.sleep(for: .seconds(8))
            guard let s = session else { return }
            var state = Self.liveState(s, status(store: store))
            state.title = "Get off at the next stop"
            state.detail = store.stop(s.option.alightStopId)?.name ?? "your stop"
            state.leg = 1
            state.stopsLeft = 1
            state.getOffNext = true
            debugHoldingAlert = true        // keep normal ticks from redrawing over it
            card.update(state, alert: (state.title, state.detail))
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }
    #endif

    /// What the lock screen card shows for this step.
    static func liveState(_ s: TripSession, _ words: Status?) -> GoActivityAttributes.ContentState {
        let leg: Int
        switch s.step {
        case .toStop, .atStop: leg = 0
        case .riding, .getOffNext: leg = 1
        case .toDestination: leg = 2
        case .arrived, .timedOut: leg = 3
        }
        let seconds = s.isAboard ? s.rideSecondsLeft : (leg == 0 ? s.busSecondsAway : nil)
        return GoActivityAttributes.ContentState(
            title: words?.title ?? "", detail: words?.detail ?? "", leg: leg,
            minutes: seconds.map { Int(($0 / 60).rounded()) },
            stopsLeft: s.isAboard ? s.stopsLeft : nil,
            getOffNext: s.step == .getOffNext)
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
