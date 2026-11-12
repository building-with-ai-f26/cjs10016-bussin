import SwiftUI
import CoreLocation

struct HomeView: View {
    let store: ShuttleStore
    let saved: SavedPlaces
    let userCoordinate: CLLocationCoordinate2D?

    private var from: CLLocationCoordinate2D { userCoordinate ?? TripView.hub }

    /// The closest stop to you, whether or not anything is running there.
    private var nearestStop: ShuttleStop? {
        store.stops.min { Walk.meters($0.coordinate, from) < Walk.meters($1.coordinate, from) }
    }

    /// The closest stop that has a bus coming. Shown only when your nearest stop has none.
    private var nearestRunningStop: ShuttleStop? {
        store.stops
            .filter { !store.runningRouteIds(at: $0).isEmpty }
            .min { Walk.meters($0.coordinate, from) < Walk.meters($1.coordinate, from) }
    }

    var body: some View {
        List {
            Section {
                NavigationLink(value: Place.search) {
                    Label("Where to?", systemImage: "magnifyingglass").foregroundStyle(.secondary)
                }
            }
            if !saved.favorites.isEmpty {
                Section("Favorites") {
                    ForEach(saved.favorites) { placeRow($0, icon: "star.fill", tint: .yellow) }
                }
            }
            if !saved.homeRecents.isEmpty {
                Section("Recent") {
                    ForEach(saved.homeRecents) { placeRow($0, icon: "clock", tint: .secondary) }
                }
            }
            if let stop = nearestStop {
                stopSection("Nearest stop", stop)
                if store.runningRouteIds(at: stop).isEmpty, let running = nearestRunningStop {
                    stopSection("Nearest stop with a bus running", running)
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
        // No title bar on Home: the search row is the first thing in the panel.
        .contentMargins(.top, 12, for: .scrollContent)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func stopSection(_ title: String, _ stop: ShuttleStop) -> some View {
        Section(title) {
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

    private func placeRow(_ d: Destination, icon: String, tint: Color) -> some View {
        NavigationLink(value: Place.trip(d)) {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(tint).frame(width: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(d.name)
                    Text(summary(for: d)).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }

    /// A quick straight-line answer, so it says "about". The trip screen has Apple's real walking times.
    private func summary(for d: Destination) -> String {
        let plan = store.planner.plan(from: userCoordinate ?? TripView.hub, to: d.coordinate)
        if let o = plan.options.first, let r = store.route(for: o.routeId) {
            return "\(r.name) · about \(Fmt.minutes(o.total))"
        }
        return plan.verdict == .tooFar ? "No shuttle goes there" : "Walk about \(Fmt.minutes(plan.walkSeconds))"
    }

    private func walkText(to stop: ShuttleStop) -> String {
        guard let me = userCoordinate else { return "Shuttle stop" }
        return "Shuttle stop · \(Fmt.minutes(Walk.seconds(me, stop.coordinate))) walk"
    }
}
