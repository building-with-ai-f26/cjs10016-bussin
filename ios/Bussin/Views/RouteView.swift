import SwiftUI

/// A route as a timeline: every stop in order, the next arrival at each,
/// and live buses drawn between the stops they're traveling between.
struct RouteView: View {
    let store: ShuttleStore
    let routeId: String

    var body: some View {
        List {
            if let route = store.route(for: routeId), let g = store.geometries[routeId] {
                let line = g.isLoop ? Array(g.stopDistances.dropLast()) : g.stopDistances
                let buses = store.trackedBuses.filter { $0.bus.routeId == routeId }
                // On a loop, buses past the last stop are heading to the first one: show them at the top.
                let wrapFrom = g.isLoop ? (line.last?.distance ?? g.length) : g.length
                Section {
                    ForEach(buses.filter { $0.distanceAlong >= wrapFrom }) { tb in
                        busRow(tb, route: route)
                    }
                    ForEach(Array(line.enumerated()), id: \.offset) { index, sd in
                        if let stop = store.stop(sd.stopId) {
                            NavigationLink(value: Place.stop(stop.id)) {
                                HStack(spacing: 14) {
                                    Circle()
                                        .fill(.white)
                                        .stroke(Color(hex: route.colorHex), lineWidth: 4)
                                        .frame(width: 14, height: 14)
                                    Text(stop.name)
                                    Spacer()
                                    if let t = store.engine.arrivals(routeId: routeId, stopId: stop.id, count: 1).first {
                                        LiveLabel(text: Fmt.eta(t))
                                    }
                                }
                            }
                        }
                        let nextDistance = index + 1 < line.count ? line[index + 1].distance : wrapFrom
                        ForEach(buses.filter { $0.distanceAlong >= sd.distance && $0.distanceAlong < nextDistance }) { tb in
                            busRow(tb, route: route)
                        }
                    }
                } header: {
                    Text(buses.isEmpty ? "Not running now"
                         : "\(buses.count) \(buses.count == 1 ? "bus" : "buses") running")
                } footer: {
                    if g.isLoop, let first = line.first.flatMap({ store.stop($0.stopId) }) {
                        Text("Loops back to \(first.name).")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle(store.route(for: routeId)?.name ?? "Route")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func busRow(_ tb: TrackedBus, route: ShuttleRoute) -> some View {
        NavigationLink(value: Place.bus(tb.id)) {
            HStack(spacing: 14) {
                RouteBadge(letter: route.letter, colorHex: route.colorHex, size: 24)
                    .clipShape(Circle())
                Text("Bus \(tb.bus.number)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let riders = tb.bus.ridersAboard, let cap = tb.bus.capacity {
                    Text("\(riders) of \(cap) aboard")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}
