import SwiftUI

/// The live trip, once you've tapped Go: what to do right now in big type, the three legs with
/// the current one marked, and a way to stop. Going back leaves the trip running; Home links here.
struct GoView: View {
    let store: ShuttleStore
    let go: GoTrip
    @Binding var path: [Place]

    var body: some View {
        if let s = go.session, let status = go.status(store: store) {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(status.title).font(.title2.weight(.bold))
                        Text(status.detail).font(.headline).foregroundStyle(Color.secondary)
                    }
                    .padding(.vertical, 6)
                    .accessibilityElement(children: .combine)
                }
                Section("Your trip") {
                    leg("Walk to \(store.stop(s.option.boardStopId)?.name ?? "the stop")", icon: "figure.walk",
                        state: legState(0, s))
                    leg(rideText(s), icon: "bus.fill", state: legState(1, s))
                    leg("Walk to \(go.destination?.name ?? "your destination")", icon: "figure.walk",
                        state: legState(2, s))
                }
                Section {
                    Button(s.isOver ? "Done" : "End trip", role: s.isOver ? nil : .destructive) {
                        go.end()
                        path = []
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .navigationTitle(go.destination?.name ?? "Trip")
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView("No trip running", systemImage: "bus",
                                   description: Text("Plan a trip and tap Go."))
        }
    }

    private enum LegState { case done, now, later }

    /// Leg 0 is the walk to the stop, 1 the ride, 2 the walk after.
    private func legState(_ leg: Int, _ s: TripSession) -> LegState {
        let current: Int
        switch s.step {
        case .toStop, .atStop: current = 0
        case .riding, .getOffNext: current = 1
        case .toDestination: current = 2
        case .arrived, .timedOut: current = 3
        }
        return leg < current ? .done : leg == current ? .now : .later
    }

    private func rideText(_ s: TripSession) -> String {
        let route = store.route(for: s.option.routeId)?.name ?? "the shuttle"
        let alight = store.stop(s.option.alightStopId)?.name ?? "your stop"
        return "Ride \(route) to \(alight)"
    }

    private func leg(_ text: String, icon: String, state: LegState) -> some View {
        HStack(spacing: RowMetrics.iconGap) {
            Image(systemName: state == .done ? "checkmark.circle.fill" : icon)
                .font(.title3)
                .foregroundStyle(state == .now ? Color.blue : Color.secondary)
                .frame(width: RowMetrics.iconColumn)
            Text(text)
                .fontWeight(state == .now ? .semibold : .regular)
                .foregroundStyle(state == .later ? Color.secondary : Color.primary)
        }
        .frame(minHeight: RowMetrics.minHeight)
        .accessibilityElement(children: .combine)
        .accessibilityValue(state == .done ? "Done" : state == .now ? "Now" : "")
    }
}
