import SwiftUI
import CoreLocation

/// The Apple Maps-style panel: always on screen, three heights, map usable behind it.
struct SheetHost: View {
    let store: ShuttleStore
    @Binding var path: [Place]          // the map reads path.last to know what to focus
    let userCoordinate: CLLocationCoordinate2D?
    let saved: SavedPlaces
    let walks: WalkTimes
    @Binding var tripSelection: TripPlanner.Option?

    static let peek = PresentationDetent.height(140)
    static let medium = PresentationDetent.fraction(0.48)
    @State private var detent: PresentationDetent = SheetHost.medium   // open where departures are visible

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(store: store, saved: saved, userCoordinate: userCoordinate)
                .navigationDestination(for: Place.self) { place in
                    switch place {
                    case .stop(let id): StopView(store: store, stopId: id)
                    case .route(let id): RouteView(store: store, routeId: id)
                    case .bus(let id): BusView(store: store, busId: id)
                    case .search: SearchView(saved: saved, path: $path)
                    case .trip(let d): TripView(store: store, saved: saved, walks: walks, destination: d,
                                                userCoordinate: userCoordinate, selection: $tripSelection)
                    }
                }
        }
        // Typing needs the whole panel; the answer sits at half height so the map shows the trip.
        .onChange(of: path) { _, new in
            if new.last == .search { detent = .large }
            else if case .trip = new.last { detent = Self.medium }
        }
        .presentationDetents([Self.peek, Self.medium, .large], selection: $detent)
        .presentationBackgroundInteraction(.enabled(upThrough: Self.medium))
        .presentationBackground(.regularMaterial)
        .interactiveDismissDisabled()
    }
}
