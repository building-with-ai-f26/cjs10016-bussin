import SwiftUI
import MapKit
import CoreLocation

struct TripView: View {
    let store: ShuttleStore
    let saved: SavedPlaces
    let walks: WalkTimes
    let destination: Destination
    let userCoordinate: CLLocationCoordinate2D?
    /// Where the trip starts, if not where you are. Nil means "My location".
    @Binding var from: Destination?
    @Binding var selection: TripPlanner.Option?
    let go: GoTrip
    let onGo: () -> Void
    @State private var reported = false
    @State private var choseWalk = false
    @State private var choseShuttle = false
    @State private var pickingFrom = false

    /// 715 Broadway stands in until location arrives (PRODUCT.md).
    static let hub = CLLocationCoordinate2D(latitude: 40.72927, longitude: -73.99394)
    private var origin: CLLocationCoordinate2D { from?.coordinate ?? userCoordinate ?? Self.hub }

    /// Go follows you live, so it only makes sense once you're at the trip's starting point.
    static let goReadyMeters = 200.0
    static func goReady(from: Destination?, me: CLLocationCoordinate2D?) -> Bool {
        guard let me else { return false }
        guard let from else { return true }
        return Walk.meters(me, from.coordinate) / Walk.detour <= goReadyMeters
    }
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

    private func report() {
        guard !reported, store.feedState == .live else { return }
        reported = true
        Analytics.planned(plan, store: store)
    }

    var body: some View {
        let plan = plan
        List {
            Section {
                Button { pickingFrom = true } label: { fromRow }
                if from == nil, userCoordinate == nil {
                    Text("Location is off, so this starts from 715 Broadway.")
                        .font(.footnote).foregroundStyle(Color.secondary)
                }
            }
            // Walking first when it's faster; the shuttle stays right below for anyone who'd rather ride.
            let walkFirst = plan.verdict == .walk && !plan.options.isEmpty
            if !walkFirst { shuttleSection(plan, title: "Shuttle") }
            walkSection(plan, title: plan.options.isEmpty || walkFirst ? "Best way there" : "Or")
            if walkFirst { shuttleSection(plan, title: "Or take the shuttle") }
            if !plan.idleRouteIds.isEmpty {
                Section {
                    Text(idleNote(plan.idleRouteIds.compactMap { store.route(for: $0)?.name }))
                        .font(.footnote).foregroundStyle(Color.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle(destination.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $pickingFrom) {
            NavigationStack {
                SearchView(saved: saved, path: .constant([]), onPick: { d, source in
                    from = d
                    pickingFrom = false
                    Analytics.capture("trip_origin_changed", ["source": source.rawValue])
                }, title: "Starting from")
                .safeAreaInset(edge: .top) {
                    if from != nil {
                        Button {
                            from = nil
                            pickingFrom = false
                            Analytics.capture("trip_origin_changed", ["source": "my_location"])
                        } label: {
                            Label("My location", systemImage: "location.fill")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 12)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { pickingFrom = false } }
                }
            }
            .presentationDetents([.large])
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    saved.toggleFavorite(destination)
                    Analytics.capture("favorite_changed", ["added": saved.isFavorite(destination)])
                } label: {
                    Image(systemName: saved.isFavorite(destination) ? "star.fill" : "star")
                }
                .accessibilityLabel(saved.isFavorite(destination) ? "Remove favorite" : "Add favorite")
            }
        }
        // Keep the chosen way chosen as times refresh. Otherwise pick the recommendation:
        // the fastest shuttle, or walking when walking is faster.
        .onChange(of: plan.options, initial: true) { _, new in
            if choseWalk { selection = nil; return }
            if let kept = new.first(where: { $0.id == selection?.id }) { selection = kept; return }
            selection = (choseShuttle || plan.verdict == .shuttle) ? new.first : nil
        }
        .task(id: legsNeeded.map { WalkTimes.key($0.0, $0.1) }) { await walks.fetch(legsNeeded) }
        // Report the answer once the walking times are real, or after 5 seconds if Apple is slow.
        .onChange(of: plan.isEstimate, initial: true) { _, estimate in if !estimate { report() } }
        .task { try? await Task.sleep(for: .seconds(5)); report() }
        .onDisappear { selection = nil }
    }

    @ViewBuilder
    private func shuttleSection(_ plan: TripPlanner.Plan, title: String) -> some View {
        if !plan.options.isEmpty {
            Section(title) {
                ForEach(plan.options) { o in
                    Button {
                        choseWalk = false; choseShuttle = true; selection = o
                        Analytics.capture("trip_option_selected", ["choice": "shuttle"])
                    } label: { optionRow(o, walk: plan.walkSeconds) }
                        .listRowBackground(selection?.id == o.id ? Color.blue.opacity(0.12) : nil)
                    if o.busAtStopNow {
                        Label("A bus is at \(store.stop(o.boardStopId)?.name ?? "the stop") right now. You're \(Fmt.minutes(o.walkToStop)) away, so it may leave without you. The time above is the next one.",
                              systemImage: "figure.run")
                            .font(.footnote).foregroundStyle(Color.secondary)
                    }
                    if selection?.id == o.id {
                        steps(o)
                        goButton(o)     // after the directions, so you read them first
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func walkSection(_ plan: TripPlanner.Plan, title: String) -> some View {
        Section(title) {
            if plan.verdict == .tooFar {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tooFarTitle(plan)).font(.headline)
                    Text("It's about \(Fmt.distance(plan.walkMeters)) away.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Button("Get directions in Apple Maps") { openInMaps() }
            } else {
                Button {
                    choseWalk = true; choseShuttle = false; selection = nil
                    Analytics.capture("trip_option_selected", ["choice": "walk"])
                } label: { walkRow(plan) }
                    .listRowBackground(selection == nil ? Color.blue.opacity(0.12) : nil)
            }
        }
    }

    private func optionRow(_ o: TripPlanner.Option, walk: Double) -> some View {
        HStack(spacing: 12) {
            if let r = store.route(for: o.routeId) { RouteBadge(letter: r.letter, colorHex: r.colorHex) }
            VStack(alignment: .leading, spacing: 2) {
                LiveLabel(text: "Bus in \(Fmt.eta(o.busArrives).lowercased())")
                Text("Arrive \(Fmt.clock(Date.now.addingTimeInterval(o.total)))" + slower(o, walk: walk))
                    .font(.footnote).foregroundStyle(Color.secondary)
            }
            Spacer()
            Text(about(o.isEstimate) + Fmt.minutes(o.total)).font(.title3.weight(.semibold)).foregroundStyle(Color.primary)
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

    /// Why there's no shuttle. When a running route does stop near the place, the trouble is the
    /// start: say so, instead of claiming the shuttles don't go there.
    private func tooFarTitle(_ plan: TripPlanner.Plan) -> String {
        let runningNearPlace = Set(store.stops
            .filter { Walk.seconds($0.coordinate, destination.coordinate) < TripPlanner.nearDestination }
            .flatMap { store.runningRouteIds(at: $0) })
            .compactMap { store.route(for: $0)?.name }.sorted()
        if let first = runningNearPlace.first {
            let start = from?.name ?? (userCoordinate == nil ? "715 Broadway" : "you")
            let names = runningNearPlace.count == 1 ? first : runningNearPlace.joined(separator: " and ")
            return "\(names) \(runningNearPlace.count == 1 ? "goes" : "go") there, but no stop is close to \(start)"
        }
        return plan.idleRouteIds.isEmpty ? "The shuttles don't go near there" : "No shuttle is running there right now"
    }

    /// "From  My location" at the top of the trip, tap to change it.
    private var fromRow: some View {
        HStack(spacing: 12) {
            Text("From").foregroundStyle(Color.secondary)
            Image(systemName: from == nil ? "location.fill" : "mappin.circle.fill")
                .foregroundStyle(from == nil ? Color.blue : Color.red)
            Text(from?.name ?? (userCoordinate == nil ? "715 Broadway" : "My location"))
                .foregroundStyle(Color.primary).lineLimit(1)
            Spacer()
            Text("Change").font(.subheadline).foregroundStyle(Color.blue)
        }
        .frame(minHeight: RowMetrics.minHeight)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Choose where this trip starts")
    }

    /// Go follows this trip live. It needs your location to know when you've boarded.
    @ViewBuilder
    private func goButton(_ o: TripPlanner.Option) -> some View {
        if !Self.goReady(from: from, me: userCoordinate), let from, userCoordinate != nil {
            Text("Go appears once you're at \(from.name).").font(.footnote).foregroundStyle(Color.secondary)
        } else {
            goButtonReady(o)
        }
    }

    @ViewBuilder
    private func goButtonReady(_ o: TripPlanner.Option) -> some View {
        Button {
            if go.isRunning { go.end(outcome: "replaced") }
            if go.start(option: o, to: destination, store: store, me: userCoordinate) { onGo() }
        } label: {
            Text("Go")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .center)
        }
        .buttonStyle(.borderedProminent)
        .disabled(userCoordinate == nil)
        .listRowSeparator(.hidden)
        if userCoordinate == nil {
            Text("Turn on location to use Go.").font(.footnote).foregroundStyle(Color.secondary)
        }
    }

    /// " · 6 min longer than walking", when it is.
    private func slower(_ o: TripPlanner.Option, walk: Double) -> String {
        o.total > walk + 30 ? " · \(Fmt.minutes(o.total - walk)) longer than walking" : ""
    }

    private func walkRow(_ plan: TripPlanner.Plan) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.walk").font(.title3).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text("Walk the whole way").foregroundStyle(Color.primary)
                Text("\(Fmt.distance(plan.walkMeters)) · arrive \(Fmt.clock(Date.now.addingTimeInterval(plan.walkSeconds)))")
                    .font(.footnote).foregroundStyle(Color.secondary)
            }
            Spacer()
            Text(about(plan.isEstimate) + Fmt.minutes(plan.walkSeconds)).font(.title3.weight(.semibold)).foregroundStyle(Color.primary)
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
