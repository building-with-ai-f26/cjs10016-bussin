import Foundation
import PostHog

enum Analytics {
    private(set) static var isEnabled = false

    /// No-op unless a real key is present (Secrets.xcconfig → Info.plist).
    static func start() {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "PostHogApiKey") as? String,
              key.hasPrefix("phc_") else { return }
        let config = PostHogConfig(apiKey: key, host: "https://us.i.posthog.com")
        // Our own named events (route_viewed etc.) replace automatic screen tracking,
        // which logs SwiftUI's internal class names like NavigationStackHostingController.
        config.captureScreenViews = false
        #if DEBUG
        config.debug = true          // prints each event to the console in test builds
        config.flushAt = 1           // send immediately instead of batching
        #endif
        PostHogSDK.shared.setup(config)
        isEnabled = true
        capture("app_opened")
    }

    static func capture(_ event: String, _ properties: [String: Any] = [:]) {
        guard isEnabled else { return }
        PostHogSDK.shared.capture(event, properties: properties)
    }

    /// One event per screen the rider opens. This is the "which routes do people
    /// actually check" evidence for the NYU pitch.
    @MainActor
    static func viewed(_ place: Place, store: ShuttleStore) {
        switch place {
        case .route(let id):
            capture("route_viewed", ["route": store.route(for: id)?.letter ?? id])
        case .stop(let id):
            capture("stop_viewed", ["stop": store.stop(id)?.name ?? id])
        case .bus(let id):
            let tb = store.trackedBuses.first { $0.id == id }
            capture("bus_viewed", [
                "route": tb.flatMap { store.route(for: $0.bus.routeId)?.letter } ?? "",
                "riders_aboard": tb?.bus.ridersAboard ?? -1,
            ])
        case .search, .trip:
            break       // the trip screen reports its own answer through planned(_:store:)
        }
    }

    /// What the planner answered. Records the route and stops, never the searched address.
    @MainActor
    static func planned(_ plan: TripPlanner.Plan, store: ShuttleStore) {
        if let o = plan.options.first {
            capture("trip_planned", [
                "route": store.route(for: o.routeId)?.letter ?? o.routeId,
                "board_stop": store.stop(o.boardStopId)?.name ?? o.boardStopId,
                "alight_stop": store.stop(o.alightStopId)?.name ?? o.alightStopId,
                "minutes": Int((o.total / 60).rounded()),
                "minutes_saved": Int(((plan.walkSeconds - o.total) / 60).rounded()),
            ])
        } else {
            capture("no_good_option", [
                "walk_minutes": Int((plan.walkSeconds / 60).rounded()),
                "too_far": plan.verdict == .tooFar,
            ])
        }
    }
}
