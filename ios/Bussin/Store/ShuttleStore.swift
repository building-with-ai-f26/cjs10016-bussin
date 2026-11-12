import Foundation
import Observation

@Observable @MainActor
final class ShuttleStore {
    enum FeedState: Equatable {
        case loading
        case live
        case stale(String)
    }

    private(set) var routes: [ShuttleRoute] = []
    private(set) var stops: [ShuttleStop] = []
    private(set) var buses: [LiveBus] = []
    private(set) var excludedRouteIds: Set<String> = []
    private(set) var feedState: FeedState = .loading

    private(set) var trackedBuses: [TrackedBus] = []
    private(set) var geometries: [String: RouteGeometry] = [:]

    var staleAfter: TimeInterval = 30
    private var lastBusUpdate: Date?
    private let api: any PassioFetching
    private var routesById: [String: ShuttleRoute] = [:]
    private var stopsById: [String: ShuttleStop] = [:]
    private var tracker = BusTracker()

    init(api: any PassioFetching = PassioAPI()) {
        self.api = api
    }

    func route(for id: String) -> ShuttleRoute? { routesById[id] }
    func stop(_ id: String) -> ShuttleStop? { stopsById[id] }

    var engine: ETAEngine { ETAEngine(geometries: geometries, buses: trackedBuses) }

    func hasBuses(_ routeId: String) -> Bool { trackedBuses.contains { $0.bus.routeId == routeId } }

    /// Routes serving a stop that have buses out right now.
    func runningRouteIds(at stop: ShuttleStop) -> [String] {
        stop.routeIds.filter { routesById[$0] != nil && hasBuses($0) }
    }

    // MARK: - Pure appliers (testable without networking)

    func apply(catalogData: Data) {
        guard let payload = try? JSONDecoder().decode(PassioStopsPayload.self, from: catalogData) else { return }
        let catalog = ShuttleCatalog.from(payload: payload)
        guard !catalog.routes.isEmpty else { return }   // never let garbage wipe a good catalog
        routes = catalog.routes
        stops = catalog.stops
        excludedRouteIds = catalog.excludedRouteIds
        routesById = Dictionary(uniqueKeysWithValues: catalog.routes.map { ($0.id, $0) })
        stopsById = Dictionary(uniqueKeysWithValues: catalog.stops.map { ($0.id, $0) })
        geometries = Dictionary(uniqueKeysWithValues: catalog.routes.compactMap { r in
            RouteGeometry.build(route: r, stops: stopsById).map { (r.id, $0) }
        })
    }

    func apply(busesData data: Data) {
        guard let payload = try? JSONDecoder().decode(PassioBusesPayload.self, from: data) else { return }
        buses = LiveBus.from(payload: payload, allowedRouteIds: Set(routesById.keys))
        trackedBuses = tracker.update(buses: buses, geometries: geometries, at: .now)
        lastBusUpdate = .now
        feedState = .live
    }

    // MARK: - Feed access

    func loadCatalogFromSnapshot() {
        guard routes.isEmpty,
              let url = Bundle.main.url(forResource: "passio-stops", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return }
        apply(catalogData: data)
    }

    func refreshCatalog() async {
        if let data = try? await api.stopsData() { apply(catalogData: data) }
    }

    func pollOnce() async {
        do {
            apply(busesData: try await api.busesData())
        } catch {
            let age = lastBusUpdate.map { Date.now.timeIntervalSince($0) } ?? .infinity
            if age >= staleAfter {
                feedState = .stale("Live feed unreachable — showing last known buses")
            }
        }
    }

    /// Call from `.task` on the root view; cancels with the view.
    func run() async {
        loadCatalogFromSnapshot()
        await refreshCatalog()
        while !Task.isCancelled {
            await pollOnce()
            try? await Task.sleep(for: .seconds(4))
        }
    }
}
