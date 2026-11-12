import SwiftUI

/// One bus: how full it is and every stop it will reach next, with clock times.
struct BusView: View {
    let store: ShuttleStore
    let busId: Int

    var body: some View {
        List {
            if let tb = store.trackedBuses.first(where: { $0.id == busId }),
               let route = store.route(for: tb.bus.routeId) {
                if let riders = tb.bus.ridersAboard, let cap = tb.bus.capacity, cap > 0 {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "person.2.fill").foregroundStyle(.secondary)
                            Text("\(riders) of \(cap) aboard")
                            Spacer()
                            Text(riders >= cap - 5 ? "Nearly full" : "Seats open")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(riders >= cap - 5 ? Color.orange : Color.secondary)
                        }
                    }
                }

                Section("Upcoming stops") {
                    ForEach(Array(store.engine.upcomingStops(busId: busId).enumerated()), id: \.element.id) { index, up in
                        if let stop = store.stop(up.stopId) {
                            NavigationLink(value: Place.stop(stop.id)) {
                                HStack(spacing: 14) {
                                    Circle()
                                        .fill(.white)
                                        .stroke(Color(hex: route.colorHex), lineWidth: 4)
                                        .frame(width: 14, height: 14)
                                    VStack(alignment: .leading, spacing: 1) {
                                        if index == 0 {
                                            Text("NEXT STOP")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(.blue)
                                        }
                                        Text(stop.name)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 1) {
                                        Text(Fmt.clock(Date.now.addingTimeInterval(up.secondsAway)))
                                            .font(.headline)
                                            .monospacedDigit()
                                        Text(up.secondsAway < 45 ? "Arriving" : "in \(Fmt.minutes(up.secondsAway))")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                        }
                    }
                }

                Section {
                    Text("Times assume the bus keeps its current pace. They update every few seconds from the live feed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("This bus isn't reporting right now.").foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var title: String {
        guard let tb = store.trackedBuses.first(where: { $0.id == busId }) else { return "Bus" }
        let letter = store.route(for: tb.bus.routeId)?.letter ?? ""
        return "Bus \(tb.bus.number) · Route \(letter)"
    }
}
