import SwiftUI
import MapKit
import CoreLocation

struct MapScreen: View {
    @State private var store = ShuttleStore()
    @State private var locationManager = CLLocationManager()
    @State private var path: [Place] = []
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var sheetShown = false       // opens once the welcome card is done
    @State private var demoBuses: [TrackedBus] = []     // debug only; always empty in release
    @State private var saved = SavedPlaces()
    @State private var walks = WalkTimes()
    @State private var tripSelection: TripPlanner.Option?
    @State private var camera: MapCameraPosition = .region(MapScreen.nyu)

    private static let nyu = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.7295, longitude: -73.9965),
        span: MKCoordinateSpan(latitudeDelta: 0.045, longitudeDelta: 0.035))

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
                    .stroke(Color(hex: route.colorHex).opacity(isDimmed(route: route.id) ? 0.15 : 1),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }

            ForEach(store.stops) { stop in
                Annotation(stop.name, coordinate: stop.coordinate) {
                    Button { path = [.stop(stop.id)] } label: {
                        Circle()
                            .fill(.white)
                            .stroke(Color(.systemGray), lineWidth: focus == .stop(stop.id) ? 4 : 2)
                            .frame(width: focus == .stop(stop.id) ? 16 : 10, height: focus == .stop(stop.id) ? 16 : 10)
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
        }
        .overlay(alignment: .top) {
            if case .stale(let message) = store.feedState {
                Text(message)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 8)
            }
        }
        .sheet(isPresented: $sheetShown) {
            SheetHost(store: store, path: $path, userCoordinate: locationManager.location?.coordinate,
                      saved: saved, walks: walks, tripSelection: $tripSelection)
        }
        .onChange(of: path) { old, new in
            withAnimation(.easeInOut(duration: 0.5)) { camera = cameraForFocus() }
            // Count forward navigation only, not going back.
            if new.count >= old.count, let place = new.last { Analytics.viewed(place, store: store) }
        }
        .onChange(of: tripSelection?.id) { _, _ in
            // Re-frame when the rider picks another option.
            guard case .trip = focus else { return }
            withAnimation(.easeInOut(duration: 0.5)) { camera = cameraForFocus() }
        }
        .onChange(of: followedBusPosition) { _, _ in
            // Follow the open bus as it moves, like the prototype's follow mode.
            guard case .bus = focus else { return }
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
        .onAppear {
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "resetWelcome") { hasSeenWelcome = false; return }
            #endif
            guard hasSeenWelcome else { return }
            startLocation()
            sheetShown = true
        }
    }

    private func startLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

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

    private var tripOrigin: CLLocationCoordinate2D { locationManager.location?.coordinate ?? TripView.hub }

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
        let lats = coords.map(\.latitude), lons = coords.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return Self.nyu }
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

#Preview { MapScreen() }
