import SwiftUI
import MapKit
import CoreLocation

struct TripView: View {
    let store: ShuttleStore
    let saved: SavedPlaces
    let walks: WalkTimes
    let destination: Destination
    let userCoordinate: CLLocationCoordinate2D?
    @Binding var selection: TripPlanner.Option?
    @State private var reported = false
    @State private var choseWalk = false

    /// 715 Broadway stands in until location arrives (PRODUCT.md).
    static let hub = CLLocationCoordinate2D(latitude: 40.72927, longitude: -73.99394)
    private var origin: CLLocationCoordinate2D { userCoordinate ?? Self.hub }
    private var plan: TripPlanner.Plan {
        store.planner.plan(from: origin, to: destination.coordinate, walks: { walks.leg($0, $1) })
    }

    /// The walks worth asking Apple Maps about: the whole way, plus to and from each shortlisted stop.
    private var legsNeeded: [(CLLocationCoordinate2D, CLLocationCoordinate2D)] {
        var legs: [(CLLocationCoordinate2D, CLLocationCoordinate2D)] = []
        // No point asking Apple for a three-hour walk.
        if Walk.seconds(origin, destination.coordinate) <= 2 * TripPlanner.tooFarToWalk {
            legs.append((origin, destination.coordinate))
        }
        for o in store.planner.candidates(from: origin, to: destination.coordinate) {
            if let b = store.stop(o.boardStopId) { legs.append((origin, b.coordinate)) }
            if let a = store.stop(o.alightStopId) { legs.append((a.coordinate, destination.coordinate)) }
        }
        return legs
    }

    private func about(_ estimate: Bool) -> String { estimate ? "about " : "" }

    private func walkingSource(_ plan: TripPlanner.Plan) -> String {
        if !plan.isEstimate { return "Walking times from Apple Maps." }
        return walks.unreachable ? "Walking times are estimates right now."
                                 : "Checking walking times with Apple Maps…"
    }

    private func report() {
        guard !reported, store.feedState == .live else { return }
        reported = true
        Analytics.planned(plan, store: store)
    }

    var body: some View {
        let plan = plan
        List {
            if userCoordinate == nil {
                Text("Location is off, so this starts from 715 Broadway.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if !plan.options.isEmpty {
                Section("Shuttle") {
                    ForEach(plan.options) { o in
                        Button { choseWalk = false; selection = o } label: { optionRow(o) }
                            .listRowBackground(selection?.id == o.id ? Color.blue.opacity(0.12) : nil)
                        if selection?.id == o.id { steps(o) }
                    }
                }
            }
            Section(plan.options.isEmpty ? "Best way there" : "Or") {
                if plan.verdict == .tooFar {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("The shuttles don't go near there").font(.headline)
                        Text("It's about \(Fmt.distance(plan.walkMeters)) away.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Button("Get directions in Apple Maps") { openInMaps() }
                } else {
                    Button { choseWalk = true; selection = nil } label: { walkRow(plan) }
                        .listRowBackground(selection == nil ? Color.blue.opacity(0.12) : nil)
                }
            }
            if plan.verdict != .tooFar {
                Section { Text(walkingSource(plan)).font(.footnote).foregroundStyle(.secondary) }
            }
            if !plan.idleRouteIds.isEmpty {
                Section {
                    Text(idleNote(plan.idleRouteIds.compactMap { store.route(for: $0)?.name }))
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle(destination.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { saved.toggleFavorite(destination) } label: {
                    Image(systemName: saved.isFavorite(destination) ? "star.fill" : "star")
                }
                .accessibilityLabel(saved.isFavorite(destination) ? "Remove favorite" : "Add favorite")
            }
        }
        // Keep the chosen route chosen as times refresh; fall back to the fastest.
        .onChange(of: plan.options, initial: true) { _, new in
            selection = choseWalk ? nil : (new.first { $0.id == selection?.id } ?? new.first)
        }
        .task(id: legsNeeded.map { WalkTimes.key($0.0, $0.1) }) { await walks.fetch(legsNeeded) }
        // Report the answer once the walking times are real, or after 5 seconds if Apple is slow.
        .onChange(of: plan.isEstimate, initial: true) { _, estimate in if !estimate { report() } }
        .task { try? await Task.sleep(for: .seconds(5)); report() }
        .onDisappear { selection = nil }
    }

    private func optionRow(_ o: TripPlanner.Option) -> some View {
        HStack(spacing: 12) {
            if let r = store.route(for: o.routeId) { RouteBadge(letter: r.letter, colorHex: r.colorHex) }
            VStack(alignment: .leading, spacing: 2) {
                LiveLabel(text: "Bus in \(Fmt.eta(o.busArrives).lowercased())")
                Text("Arrive \(Fmt.clock(Date.now.addingTimeInterval(o.total)))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            Text(about(o.isEstimate) + Fmt.minutes(o.total)).font(.title3.weight(.semibold)).foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func steps(_ o: TripPlanner.Option) -> some View {
        let board = store.stop(o.boardStopId)?.name ?? "the stop"
        let alight = store.stop(o.alightStopId)?.name ?? "your stop"
        let route = store.route(for: o.routeId)?.name ?? "the shuttle"
        Label("Walk \(Fmt.minutes(o.walkToStop)) to \(board)", systemImage: "figure.walk")
        Label("Ride \(route) \(o.stopCount) \(o.stopCount == 1 ? "stop" : "stops") to \(alight) · \(Fmt.minutes(o.ride))",
              systemImage: "bus.fill")
        Label("Walk \(Fmt.minutes(o.walkFromStop)) to \(destination.name)", systemImage: "figure.walk")
    }

    private func walkRow(_ plan: TripPlanner.Plan) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.walk").font(.title3).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text("Walk the whole way").foregroundStyle(.primary)
                Text("\(Fmt.distance(plan.walkMeters)) · arrive \(Fmt.clock(Date.now.addingTimeInterval(plan.walkSeconds)))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            Text(about(plan.isEstimate) + Fmt.minutes(plan.walkSeconds)).font(.title3.weight(.semibold)).foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }

    private func idleNote(_ names: [String]) -> String {
        names.count == 1
            ? "\(names[0]) also stops near here, but isn't running right now."
            : "\(names.joined(separator: ", ")) also stop near here, but aren't running right now."
    }

    private func openInMaps() {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: destination.coordinate))
        item.name = destination.name
        item.openInMaps()
    }
}
