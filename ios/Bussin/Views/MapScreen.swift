import SwiftUI
import MapKit
import CoreLocation

struct MapScreen: View {
    @State private var store = ShuttleStore()
    @State private var locationManager = CLLocationManager()

    private static let nyu = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.7295, longitude: -73.9965),
        span: MKCoordinateSpan(latitudeDelta: 0.045, longitudeDelta: 0.035))

    var body: some View {
        Map(initialPosition: .region(Self.nyu)) {
            UserAnnotation()

            ForEach(store.routes) { route in
                MapPolyline(coordinates: route.coordinates)
                    .stroke(Color(hex: route.colorHex),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }

            ForEach(store.stops) { stop in
                Annotation(stop.name, coordinate: stop.coordinate) {
                    Circle()
                        .fill(.white)
                        .stroke(Color(.systemGray), lineWidth: 2)
                        .frame(width: 10, height: 10)
                }
                .annotationTitles(.hidden)
            }

            ForEach(store.buses) { bus in
                Annotation("Bus \(bus.number)", coordinate: bus.coordinate) {
                    BusMarker(letter: store.route(for: bus.routeId)?.letter ?? "?",
                              colorHex: store.route(for: bus.routeId)?.colorHex ?? "#8E8E93",
                              heading: bus.headingDegrees,
                              isStale: bus.isStale)
                }
                .annotationTitles(.hidden)
            }
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
        .task { await store.run() }
        .onAppear { locationManager.requestWhenInUseAuthorization() }
    }
}

#Preview { MapScreen() }
