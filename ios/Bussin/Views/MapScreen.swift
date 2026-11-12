import SwiftUI
import MapKit
import CoreLocation

struct MapScreen: View {
    @State private var store = ShuttleStore()
    @State private var locationManager = CLLocationManager()
    @State private var path: [Place] = []
    @State private var sheetShown = true
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
        case nil: return nil
        }
    }

    var body: some View {
        Map(position: $camera) {
            // Paint order = z-order: routes, then stops, then buses, then you on top.
            ForEach(store.routes) { route in
                MapPolyline(coordinates: route.coordinates)
                    .stroke(Color(hex: route.colorHex).opacity(isDimmed(route: route.id) ? 0.15 : 1),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }

            ForEach(store.stops) { stop in
                Annotation(stop.name, coordinate: stop.coordinate) {
                    Circle()
                        .fill(.white)
                        .stroke(Color(.systemGray), lineWidth: focus == .stop(stop.id) ? 4 : 2)
                        .frame(width: focus == .stop(stop.id) ? 16 : 10, height: focus == .stop(stop.id) ? 16 : 10)
                        .opacity(stop.routeIds.contains { !isDimmed(route: $0) } ? 1 : 0.25)
                }
                .annotationTitles(.hidden)
            }

            ForEach(store.trackedBuses) { tracked in
                let bus = tracked.bus
                Annotation("Bus \(bus.number)", coordinate: bus.coordinate) {
                    BusMarker(letter: store.route(for: bus.routeId)?.letter ?? "?",
                              colorHex: store.route(for: bus.routeId)?.colorHex ?? "#8E8E93",
                              heading: bus.headingDegrees,
                              isStale: bus.isStale)
                        .opacity(isDimmed(route: bus.routeId) ? 0.2 : 1)
                }
                .annotationTitles(.hidden)
            }

            UserAnnotation()
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
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
            SheetHost(store: store, path: $path, userCoordinate: locationManager.location?.coordinate)
        }
        .onChange(of: path) { _, _ in
            withAnimation(.easeInOut(duration: 0.5)) { camera = cameraForFocus() }
        }
        .task { await store.run() }
        #if DEBUG
        .task { await openDebugLaunchPlace() }
        #endif
        .onAppear {
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()
        }
    }

    #if DEBUG
    /// Test shortcut, like the prototype's ?view= links:
    /// `xcrun simctl launch booted com.schwaigs.bussin -place route:74769` (or stop:6545, bus:first).
    private func openDebugLaunchPlace() async {
        guard let raw = UserDefaults.standard.string(forKey: "place") else { return }
        try? await Task.sleep(for: .seconds(4))   // let the catalog and first bus poll land
        let parts = raw.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        switch parts[0] {
        case "route": path = [.route(parts[1])]
        case "stop": path = [.stop(parts[1])]
        case "bus":
            let id = parts[1] == "first" ? store.trackedBuses.first?.id : Int(parts[1])
            if let id { path = [.bus(id)] }
        default: break
        }
    }
    #endif

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
        case nil:
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
