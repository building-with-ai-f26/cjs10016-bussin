import SwiftUI
import MapKit
import CoreLocation

struct MapScreen: View {
    @State private var store = ShuttleStore()
    @State private var location = LocationAccess()
    @State private var path: [Place] = []
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var sheetShown = false       // opens once the welcome card is done
    @State private var demoBuses: [TrackedBus] = []     // debug only; always empty in release
    @State private var saved = SavedPlaces()
    @State private var walks = WalkTimes()
    @State private var tripSelection: TripPlanner.Option?
    @State private var camera: MapCameraPosition = .region(MapScreen.nyu)
    @State private var detent: PresentationDetent = SheetHost.medium

    /// Where every shuttle route runs: the Manhattan stretch of all seven, from the Village and
    /// Tribeca up the East Side to Langone. Route A's tail to MetroTech in Brooklyn is left out on
    /// purpose, so the opening view isn't pulled south. Opening Route A still frames the whole line.
    private static let routeArea = [
        CLLocationCoordinate2D(latitude: 40.7152, longitude: -74.0086),
        CLLocationCoordinate2D(latitude: 40.7457, longitude: -73.9740),
    ]

    /// The opening view, and the one Home returns to: all the routes, sitting above the panel.
    private static let nyu = region(fitting: routeArea)

    /// What the sheet is showing right now; the map highlights the same thing.
    private var focus: Place? { path.last }

    private var focusedRouteIds: Set<String>? {
        switch focus {
        case .route(let id): return [id]
        case .stop(let id): return Set(store.stop(id)?.routeIds ?? [])
        case .bus(let id): return store.trackedBuses.first { $0.id == id }.map { [$0.bus.routeId] }
        case .trip: return tripSelection.map { [$0.routeId] } ?? []   // walking: every route dims
        case .search, nil: return nil
        }
    }

    var body: some View {
        MapReader { proxy in
        Map(position: $camera) {
            // Paint order = z-order: routes, then stops, then buses, then you on top.
            ForEach(store.routes) { route in
                MapPolyline(coordinates: route.coordinates)
                    .stroke(Color(hex: route.colorHex).opacity(routeOpacity(route.id)),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }

            // On a trip, the stretch you'd actually ride, bold over its faded route.
            if let ride = rideStretch {
                MapPolyline(coordinates: ride.coordinates)
                    .stroke(Color(hex: ride.colorHex),
                            style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
            }

            ForEach(store.stops) { stop in
                Annotation(stop.name, coordinate: stop.coordinate) {
                    let big = focus == .stop(stop.id) || tripStopIds.contains(stop.id)
                    Button { path = [.stop(stop.id)] } label: {
                        Circle()
                            .fill(.white)
                            .stroke(tripStopIds.contains(stop.id) ? rideColor : Color(.systemGray), lineWidth: big ? 4 : 2)
                            .frame(width: big ? 16 : 10, height: big ? 16 : 10)
                            .frame(width: 32, height: 32)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(stop.name)
                    .opacity(stop.routeIds.contains { !isDimmed(route: $0) } ? 1 : 0.25)
                }
                .annotationTitles(.hidden)
            }

            ForEach(store.trackedBuses + demoBuses) { tracked in
                let bus = tracked.bus
                Annotation("Bus \(bus.number)", coordinate: bus.coordinate) {
                    GlidingMarker(coordinate: bus.coordinate, proxy: proxy) {
                    Button { path = [.bus(bus.id)] } label: {
                        BusMarker(letter: store.route(for: bus.routeId)?.letter ?? "?",
                                  colorHex: store.route(for: bus.routeId)?.colorHex ?? "#8E8E93",
                                  heading: bus.headingDegrees,
                                  isStale: bus.isStale,
                                  isSelected: focus == .bus(bus.id))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Route \(store.route(for: bus.routeId)?.letter ?? "") bus \(bus.number)")
                    .opacity(busDimmed(bus) ? 0.2 : 1)
                    }
                }
                .annotationTitles(.hidden)
            }

            if case .trip(let d) = focus {
                ForEach(Array(walkLegs(to: d).enumerated()), id: \.offset) { _, leg in
                    MapPolyline(coordinates: leg)
                        .stroke(Color.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [0.1, 8]))
                }
                Marker(d.name, coordinate: d.coordinate).tint(.red)
            }

            UserAnnotation()
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        // Tapping the map itself shrinks the panel out of the way. A tap on a stop or bus opens it
        // instead: the map hears that tap too, so skip anything on or right next to a marker.
        .onTapGesture { point in
            guard !isOnMarker(point, proxy: proxy) else { return }
            withAnimation { detent = SheetHost.peek }
        }
        }
        .overlay(alignment: .top) {
            if case .stale(let message) = store.feedState {
                Text(message)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .modifier(GlassCapsule())
                    .padding(.top, 8)
            }
        }
        .sheet(isPresented: $sheetShown) {
            SheetHost(store: store, path: $path, userCoordinate: location.coordinate,
                      locationDenied: location.isDenied,
                      saved: saved, walks: walks, tripSelection: $tripSelection, detent: $detent)
        }
        .onChange(of: path) { old, new in
            withAnimation(.easeInOut(duration: 0.5)) { camera = cameraForFocus() }
            // A saved place opened from Home. (Search results report themselves in SearchView.)
            if case .trip(let d)? = new.last, old.isEmpty {
                Analytics.capture("place_selected", ["source": saved.source(of: d).rawValue])
            }
            // Count forward navigation only, not going back.
            if new.count >= old.count, let place = new.last { Analytics.viewed(place, store: store) }
        }
        .onChange(of: tripSelection?.id) { _, _ in
            // Re-frame when the rider picks another option.
            guard case .trip = focus else { return }
            withAnimation(.easeInOut(duration: 0.5)) { camera = cameraForFocus() }
        }
        .onChange(of: followedBusPosition) { _, _ in
            // Follow the open bus as it moves, like the prototype's follow mode. Once the rider
            // pinches or drags the map, stop: re-centering every 4 seconds undid their zoom.
            // Opening the bus again starts following again.
            guard case .bus = focus, !camera.positionedByUser else { return }
            withAnimation(.easeInOut(duration: 1)) { camera = cameraForFocus() }
        }
        .task { await store.run() }
        #if DEBUG
        .task { await openDebugLaunchPlace() }
        .task { await runDemoBus() }
        #endif
        .fullScreenCover(isPresented: .constant(!hasSeenWelcome)) {
            WelcomeView {
                Analytics.capture("onboarding_completed")
                hasSeenWelcome = true
                startLocation()
                sheetShown = true
            }
        }
        .onChange(of: store.feedState) { old, new in
            // PRD risk test: how often do riders see "Can't reach live bus data"?
            if ServiceStatus.feedJustWentDown(from: old, to: new) { Analytics.capture("feed_unreachable") }
        }
        .onChange(of: location.status, initial: true) { _, status in Analytics.locationPermission(status) }
        .onAppear {
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "resetWelcome") { hasSeenWelcome = false; return }
            #endif
            guard hasSeenWelcome else { return }
            startLocation()
            sheetShown = true
        }
    }

    private func startLocation() { location.start() }

    #if DEBUG
    /// `-demoBus YES` adds a pretend bus that hops 200 m north every 4 seconds, so the sliding
    /// between updates can be checked without waiting for a real bus to drive past.
    private func runDemoBus() async {
        guard UserDefaults.standard.bool(forKey: "demoBus") else { return }
        var lat = 40.733      // just north of Washington Square, clear of the panel
        while !Task.isCancelled {
            let bus = LiveBus(id: -1, number: "DEMO", routeId: "demo",
                              coordinate: .init(latitude: lat, longitude: -74.0005), headingDegrees: 0,
                              ridersAboard: nil, capacity: nil, isStale: false)
            demoBuses = [TrackedBus(bus: bus, distanceAlong: 0, speed: 4)]
            lat += 0.0018
            try? await Task.sleep(for: .seconds(4))
        }
    }

    /// Test shortcut, like the prototype's ?view= links:
    /// `xcrun simctl launch booted com.schwaigs.bussin -place route:74769` (or stop:6545, bus:first).
    private func openDebugLaunchPlace() async {
        guard let raw = UserDefaults.standard.string(forKey: "place") else { return }
        try? await Task.sleep(for: .seconds(4))   // let the catalog and first bus poll land
        if raw == "search" { path = [.search]; return }
        let parts = raw.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        switch parts[0] {
        case "route": path = [.route(parts[1])]
        case "stop": path = [.stop(parts[1])]
        case "bus":
            let id = parts[1] == "first" ? store.trackedBuses.first?.id : Int(parts[1])
            if let id { path = [.bus(id)] }
        case "trip":    // -place trip:40.6943,-73.9865  (Tandon)
            let ll = parts[1].split(separator: ",").compactMap { Double($0) }
            if ll.count == 2 {
                path = [.trip(Destination(name: "Test destination", subtitle: "", latitude: ll[0], longitude: ll[1]))]
            }
        default: break
        }
    }
    #endif

    private var tripOrigin: CLLocationCoordinate2D { location.coordinate ?? TripView.hub }

    /// Dotted walking lines: to the stop and from the stop, or straight there if walking.
    /// Each follows real streets once Apple Maps has answered, and is a straight line until then.
    private func walkLegs(to d: Destination) -> [[CLLocationCoordinate2D]] {
        var ends = [(tripOrigin, d.coordinate)]
        if let o = tripSelection, let board = store.stop(o.boardStopId), let alight = store.stop(o.alightStopId) {
            ends = [(tripOrigin, board.coordinate), (alight.coordinate, d.coordinate)]
        }
        return ends.map { walks.path($0.0, $0.1) ?? [$0.0, $0.1] }
    }

    /// Changes whenever the open bus reports a new position.
    private var followedBusPosition: String {
        guard case .bus(let id) = focus,
              let b = store.trackedBuses.first(where: { $0.id == id }) else { return "" }
        return "\(b.bus.coordinate.latitude),\(b.bus.coordinate.longitude)"
    }

    /// Is this screen point on a stop or bus? Stops are 32 pt targets; buses get more room
    /// because they slide toward their newest position between feed updates.
    private func isOnMarker(_ point: CGPoint, proxy: MapProxy) -> Bool {
        func near(_ c: CLLocationCoordinate2D, within r: CGFloat) -> Bool {
            guard let s = proxy.convert(c, to: .local) else { return false }
            return hypot(s.x - point.x, s.y - point.y) <= r
        }
        return store.stops.contains { near($0.coordinate, within: 22) }
            || (store.trackedBuses + demoBuses).contains { near($0.bus.coordinate, within: 44) }
    }

    /// The shuttle option picked on the trip screen, if one is showing.
    private var tripRide: TripPlanner.Option? {
        guard case .trip = focus else { return nil }
        return tripSelection
    }

    /// Where you'd get on and off, ringed in the route's color on the map.
    private var tripStopIds: Set<String> {
        guard let o = tripRide else { return [] }
        return [o.boardStopId, o.alightStopId]
    }

    private var rideColor: Color {
        Color(hex: tripRide.flatMap { store.route(for: $0.routeId)?.colorHex } ?? "#8E8E93")
    }

    private var rideStretch: (coordinates: [CLLocationCoordinate2D], colorHex: String)? {
        guard let o = tripRide, let g = store.geometries[o.routeId], let r = store.route(for: o.routeId)
        else { return nil }
        return (g.coordinates(from: o.boardDistance, along: o.rideMeters), r.colorHex)
    }

    /// Full color normally; faded behind the ride stretch on a trip; nearly gone when another route is in focus.
    private func routeOpacity(_ id: String) -> Double {
        if tripRide?.routeId == id { return 0.3 }
        return isDimmed(route: id) ? 0.15 : 1
    }

    private func busDimmed(_ bus: LiveBus) -> Bool {
        if case .bus(let id) = focus { return bus.id != id }   // a single bus: only it stays bright
        return isDimmed(route: bus.routeId)
    }

    private func isDimmed(route id: String) -> Bool {
        guard let focused = focusedRouteIds else { return false }
        return !focused.contains(id)
    }

    // MARK: - Camera

    private func cameraForFocus() -> MapCameraPosition {
        switch focus {
        case .route(let id):
            guard let r = store.route(for: id) else { return .region(Self.nyu) }
            return .region(regionAbovePanel(fitting: r.coordinates))
        case .stop(let id):
            guard let s = store.stop(id) else { return .region(Self.nyu) }
            return .region(regionAbovePanel(fitting: [s.coordinate], minSpan: 0.008))
        case .bus(let id):
            guard let b = store.trackedBuses.first(where: { $0.id == id }) else { return .region(Self.nyu) }
            return .region(regionAbovePanel(fitting: [b.bus.coordinate], minSpan: 0.01))
        case .trip(let d):
            var pts = [tripOrigin, d.coordinate]
            if let o = tripSelection {
                pts += [o.boardStopId, o.alightStopId].compactMap { store.stop($0)?.coordinate }
            }
            return .region(regionAbovePanel(fitting: pts))
        case .search, nil:
            return .region(Self.nyu)
        }
    }

    /// A region that shows `coords` in the top half of the screen, above the panel.
    private func regionAbovePanel(fitting coords: [CLLocationCoordinate2D], minSpan: Double = 0.005) -> MKCoordinateRegion {
        Self.region(fitting: coords, minSpan: minSpan)
    }

    private static func region(fitting coords: [CLLocationCoordinate2D], minSpan: Double = 0.005) -> MKCoordinateRegion {
        let lats = coords.map(\.latitude), lons = coords.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else {
            return MKCoordinateRegion(center: .init(latitude: 40.7295, longitude: -73.9965),
                                      span: .init(latitudeDelta: 0.045, longitudeDelta: 0.035))
        }
        // The visible area above a medium panel is about half the screen; pad 30%.
        let latSpan = max(minSpan, (maxLat - minLat) * 1.3) / 0.5
        let lonSpan = max(minSpan, (maxLon - minLon) * 1.3)
        let span = MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: max(lonSpan, latSpan * 0.6))
        // Shift the map center south so the fitted area sits in the top half.
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2 - latSpan / 4,
                                            longitude: (minLon + maxLon) / 2)
        return MKCoordinateRegion(center: center, span: span)
    }
}

/// A floating capsule over the map: Liquid Glass on iOS 26 and later, frosted before that.
private struct GlassCapsule: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content.background(.ultraThinMaterial, in: Capsule())
        }
    }
}

#Preview { MapScreen() }
