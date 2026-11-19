import SwiftUI
import CoreLocation

/// The Apple Maps-style panel: always on screen, three heights, map usable behind it.
struct SheetHost: View {
    let store: ShuttleStore
    @Binding var path: [Place]          // the map reads path.last to know what to focus
    let userCoordinate: CLLocationCoordinate2D?
    let locationDenied: Bool
    let saved: SavedPlaces
    let walks: WalkTimes
    @Binding var tripSelection: TripPlanner.Option?
    let go: GoTrip

    static let peek = PresentationDetent.height(140)
    static let medium = PresentationDetent.fraction(0.48)
    /// Owned by MapScreen, so tapping the map can shrink the panel. Opens at medium, where departures show.
    @Binding var detent: PresentationDetent

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(store: store, saved: saved, userCoordinate: userCoordinate, locationDenied: locationDenied, go: go)
                .navigationDestination(for: Place.self) { place in
                    switch place {
                    case .stop(let id): StopView(store: store, stopId: id)
                    case .route(let id): RouteView(store: store, routeId: id)
                    case .bus(let id): BusView(store: store, busId: id)
                    case .search: SearchView(saved: saved, path: $path)
                    case .trip(let d): TripView(store: store, saved: saved, walks: walks, destination: d,
                                                userCoordinate: userCoordinate, selection: $tripSelection,
                                                go: go, onGo: { path = [.go] })
                    case .go: GoView(store: store, go: go, path: $path)
                    }
                }
        }
        // Typing needs the whole panel; the answer sits at half height so the map shows the trip.
        // Shrunk by a map tap: one tap anywhere on the panel brings it back, like Apple Maps.
        // Only while shrunk, so at other heights every row and button works as usual.
        .overlay {
            if detent == Self.peek {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation { detent = Self.medium } }
                    .accessibilityLabel("Show panel")
                    .accessibilityAddTraits(.isButton)
            }
        }
        .onChange(of: path) { _, new in
            if new.last == .search { detent = .large }
            else if !new.isEmpty, detent == Self.peek { detent = Self.medium }   // opened from the map: show it
            else if case .trip = new.last { detent = Self.medium }
        }
        .presentationDetents([Self.peek, Self.medium, .large], selection: $detent)
        .presentationBackgroundInteraction(.enabled(upThrough: Self.medium))
        .modifier(PanelBackground())
        .interactiveDismissDisabled()
    }
}

/// On iOS 26 and later the system draws the panel as Liquid Glass, so leave it alone.
/// Older iOS has no Liquid Glass and gets the frosted material it had before.
private struct PanelBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
        } else {
            content.presentationBackground(.regularMaterial)
        }
    }
}
