import SwiftUI
import CoreLocation

struct HomeView: View {
    let store: ShuttleStore
    let saved: SavedPlaces
    let userCoordinate: CLLocationCoordinate2D?
    let locationDenied: Bool
    @Environment(\.openURL) private var openURL

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
                    HStack(spacing: RowMetrics.iconGap) {
                        Image(systemName: "magnifyingglass")
                            .font(.title3)
                            .frame(width: RowMetrics.iconColumn)
                        Text("Where to?")
                    }
                    .foregroundStyle(.secondary)
                    .frame(minHeight: RowMetrics.minHeight)
                }
            }
            if locationDenied {
                Section {
                    noticeRow(icon: "location.slash.fill", title: "Location is off",
                              detail: "Turn it on to see your nearest stop and walking times.")
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
            }
            if let status = ServiceStatus.notice(feed: store.feedState, busCount: store.trackedBuses.count) {
                Section { noticeRow(icon: status.icon, title: status.title, detail: status.detail) }
            }
            if !saved.favorites.isEmpty {
                Section("Favorites") {
                    ForEach(saved.favorites) { placeRow($0, icon: "star.fill", tint: .yellow, source: .favorite) }
                }
            }
            if !saved.homeRecents.isEmpty {
                Section("Recent") {
                    ForEach(saved.homeRecents) { placeRow($0, icon: "clock", tint: .secondary, source: .recent) }
                }
            }
            if let stop = nearestStop {
                stopSection(locationDenied ? "Nearest stop to 715 Broadway" : "Nearest stop", stop)
                if store.runningRouteIds(at: stop).isEmpty, let running = nearestRunningStop {
                    stopSection("Nearest stop with a bus running", running)
                }
            }

            Section("All routes") {
                ForEach(store.routes) { route in
                    let count = store.trackedBuses.filter { $0.bus.routeId == route.id }.count
                    NavigationLink(value: Place.route(route.id)) {
                        HStack(spacing: RowMetrics.iconGap) {
                            RouteBadge(letter: route.letter, colorHex: route.colorHex)
                                .opacity(count > 0 ? 1 : 0.45)
                                .frame(width: RowMetrics.iconColumn)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(route.name)
                                Text(count > 0 ? "\(count) \(count == 1 ? "bus" : "buses") running" : "Not running now")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section {
                EmptyView()
            } footer: {
                Text("Not an official NYU app · [Privacy](https://building-with-ai-f26.github.io/cjs10016-bussin/privacy.html)")
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        // No title bar on Home: the search row is the first thing in the panel.
        .listSectionSpacing(RowMetrics.sectionGap)
        .contentMargins(.top, 0, for: .scrollContent)
        // Home has no title bar, so without this the only place to grab the panel is the thin
        // handle. This strip sits above the list and doesn't scroll, so dragging it resizes the panel.
        .safeAreaInset(edge: .top, spacing: 0) {
            Color.clear
                .frame(height: RowMetrics.grabStrip)
                .contentShape(Rectangle())
                .accessibilityHidden(true)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func noticeRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: RowMetrics.iconGap) {
            Image(systemName: icon).font(.title3).foregroundStyle(.secondary).frame(width: RowMetrics.iconColumn)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func stopSection(_ title: String, _ stop: ShuttleStop) -> some View {
        Section(title) {
            NavigationLink(value: Place.stop(stop.id)) {
                HStack(spacing: RowMetrics.iconGap) {
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
                Text("No buses running here right now.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.leading, RowMetrics.labelIndent)
                    .frame(minHeight: RowMetrics.minHeight)
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

    private func placeRow(_ d: Destination, icon: String, tint: Color, source: Analytics.PlaceSource) -> some View {
        NavigationLink(value: Place.trip(d)) {
            HStack(spacing: RowMetrics.iconGap) {
                Image(systemName: icon).font(.title3).foregroundStyle(tint).frame(width: RowMetrics.iconColumn)
                VStack(alignment: .leading, spacing: 1) {
                    Text(d.name)
                    Text(summary(for: d)).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: RowMetrics.minHeight)
        }
        .simultaneousGesture(TapGesture().onEnded { Analytics.capture("place_selected", ["source": source.rawValue]) })
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
