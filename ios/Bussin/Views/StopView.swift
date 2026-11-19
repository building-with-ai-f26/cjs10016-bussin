import SwiftUI

struct StopView: View {
    let store: ShuttleStore
    let stopId: String
    /// Routes whose full list of buses is open. Tapping a route opens or closes it.
    @State private var expanded: Set<String> = []

    var body: some View {
        List {
            if let stop = store.stop(stopId) {
                let running = store.runningRouteIds(at: stop)
                Section("Departures") {
                    if running.isEmpty {
                        Text("No buses running here right now.").foregroundStyle(.secondary)
                    }
                    ForEach(store.engine.departures(stopId: stopId, routeIds: running)) { dep in
                        if let route = store.route(for: dep.routeId) {
                            Button { toggle(route.id) } label: {
                                HStack(spacing: 8) {
                                    DepartureRow(route: route, next: dep.next, then: dep.then)
                                    Image(systemName: "chevron.right")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                        .rotationEffect(.degrees(expanded.contains(route.id) ? 90 : 0))
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint(expanded.contains(route.id) ? "Hides the list of buses" : "Shows every bus in the next hour")
                            if expanded.contains(route.id) { upcomingRows(route) }
                        }
                    }
                }
                let idle = stop.routeIds.compactMap { store.route(for: $0) }.filter { !store.hasBuses($0.id) }
                if !idle.isEmpty {
                    Section {
                        Text(idleNote(idle.map(\.name)))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle(store.stop(stopId)?.name ?? "Stop")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ routeId: String) {
        withAnimation(.snappy) {
            if expanded.contains(routeId) { expanded.remove(routeId) } else { expanded.insert(routeId) }
        }
        if expanded.contains(routeId) {
            Analytics.capture("upcoming_buses_opened", ["route": store.route(for: routeId)?.letter ?? ""])
        }
    }

    /// Every bus due here in the next hour: "3 min · 3:42 · Bus 2147", then a way to the whole route.
    @ViewBuilder
    private func upcomingRows(_ route: ShuttleRoute) -> some View {
        let list = store.engine.upcoming(routeId: route.id, stopId: stopId, within: 3600)
        ForEach(list) { a in
            HStack {
                Text(Fmt.eta(a.seconds)).font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(a.seconds < 45 ? Color.green : Color.primary)
                Text(Fmt.clock(Date.now.addingTimeInterval(a.seconds)))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(busLabel(a)).font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.leading, RowMetrics.labelIndent)
            .accessibilityElement(children: .combine)
        }
        if list.isEmpty {
            Text("Nothing else in the next hour.")
                .font(.subheadline).foregroundStyle(.secondary)
                .padding(.leading, RowMetrics.labelIndent)
        }
        NavigationLink(value: Place.route(route.id)) {
            Text("See all of \(route.name)").font(.subheadline)
        }
        .padding(.leading, RowMetrics.labelIndent)
    }

    /// "Bus 2147", or "Bus 2147 again" when it's the same bus coming back round the loop.
    private func busLabel(_ a: ETAEngine.Arrival) -> String {
        let number = store.trackedBuses.first { $0.id == a.busId }?.bus.number ?? "\(a.busId)"
        return a.lap == 0 ? "Bus \(number)" : "Bus \(number) again"
    }

    private func idleNote(_ names: [String]) -> String {
        names.count == 1
            ? "\(names[0]) also stops here, but isn't running right now."
            : "\(names.joined(separator: ", ")) also stop here, but aren't running right now."
    }
}
