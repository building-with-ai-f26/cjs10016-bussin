import SwiftUI
import CoreLocation

struct HomeView: View {
    let store: ShuttleStore
    let userCoordinate: CLLocationCoordinate2D?

    /// 715 Broadway stands in until location arrives (PRODUCT.md).
    private static let hub = CLLocationCoordinate2D(latitude: 40.72927, longitude: -73.99394)

    private var nearestStop: ShuttleStop? {
        let from = userCoordinate ?? Self.hub
        return store.stops
            .filter { !store.runningRouteIds(at: $0).isEmpty }
            .min { Walk.meters($0.coordinate, from) < Walk.meters($1.coordinate, from) }
            ?? store.stop("6545")
    }

    var body: some View {
        List {
            if let stop = nearestStop {
                Section("Nearest stop") {
                    NavigationLink(value: Place.stop(stop.id)) {
                        HStack(spacing: 12) {
                            Image(systemName: "bus.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(.blue, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(stop.name).font(.headline)
                                Text(userCoordinate == nil ? "Shuttle stop" : walkText(to: stop))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    let deps = store.engine.departures(stopId: stop.id, routeIds: store.runningRouteIds(at: stop))
                    if deps.isEmpty {
                        Text("No buses running here right now.").foregroundStyle(.secondary)
                    }
                    ForEach(deps) { dep in
                        if let route = store.route(for: dep.routeId) {
                            NavigationLink(value: Place.route(route.id)) {
                                DepartureRow(route: route, next: dep.next, then: dep.then)
                            }
                        }
                    }
                }
            }

            Section("All routes") {
                ForEach(store.routes) { route in
                    let count = store.trackedBuses.filter { $0.bus.routeId == route.id }.count
                    NavigationLink(value: Place.route(route.id)) {
                        HStack(spacing: 12) {
                            RouteBadge(letter: route.letter, colorHex: route.colorHex)
                                .opacity(count > 0 ? 1 : 0.45)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(route.name)
                                Text(count > 0 ? "\(count) \(count == 1 ? "bus" : "buses") running" : "Not running now")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("Bussin")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func walkText(to stop: ShuttleStop) -> String {
        guard let me = userCoordinate else { return "Shuttle stop" }
        return "Shuttle stop · \(Fmt.minutes(Walk.seconds(me, stop.coordinate))) walk"
    }
}
