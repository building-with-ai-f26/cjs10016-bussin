import SwiftUI
import CoreLocation

/// The Apple Maps-style panel: always on screen, three heights, map usable behind it.
struct SheetHost: View {
    let store: ShuttleStore
    @Binding var path: [Place]          // the map reads path.last to know what to focus
    let userCoordinate: CLLocationCoordinate2D?

    static let peek = PresentationDetent.height(140)
    static let medium = PresentationDetent.fraction(0.48)
    @State private var detent: PresentationDetent = SheetHost.medium   // open where departures are visible

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(store: store, userCoordinate: userCoordinate)
                .navigationDestination(for: Place.self) { place in
                    switch place {
                    case .stop(let id): StopView(store: store, stopId: id)
                    case .route(let id): RouteView(store: store, routeId: id)
                    case .bus(let id): BusView(store: store, busId: id)
                    }
                }
        }
        .presentationDetents([Self.peek, Self.medium, .large], selection: $detent)
        .presentationBackgroundInteraction(.enabled(upThrough: Self.medium))
        .presentationBackground(.regularMaterial)
        .interactiveDismissDisabled()
    }
}

// Temporary stand-in so the build stays green; replaced in the next task.
struct BusView: View {
    let store: ShuttleStore
    let busId: Int
    var body: some View { Text("Bus \(busId)") }
}
