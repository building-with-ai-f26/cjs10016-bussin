import SwiftUI

struct StopView: View {
    let store: ShuttleStore
    let stopId: String

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
                            NavigationLink(value: Place.route(route.id)) {
                                DepartureRow(route: route, next: dep.next, then: dep.then)
                            }
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

    private func idleNote(_ names: [String]) -> String {
        names.count == 1
            ? "\(names[0]) also stops here, but isn't running right now."
            : "\(names.joined(separator: ", ")) also stop here, but aren't running right now."
    }
}
