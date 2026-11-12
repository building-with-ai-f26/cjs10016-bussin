import SwiftUI
import MapKit

/// Makes a map marker slide to its new position instead of jumping.
///
/// The feed moves each bus every 4 seconds, and MapKit places an annotation at its new
/// coordinate instantly. So when the coordinate changes, this view first shifts its content
/// back to where it was on screen, then animates that shift away over one feed interval.
/// The animation runs on the GPU; nothing is recomputed per frame.
struct GlidingMarker<Content: View>: View {
    let coordinate: CLLocationCoordinate2D
    let proxy: MapProxy
    @ViewBuilder var content: Content

    static var interval: Double { 4.0 }          // seconds between feed updates
    static var maxSlidePoints: CGFloat { 150 }   // further than this is a glitch or a reroute: just jump

    @State private var offset: CGSize = .zero

    var body: some View {
        content
            .offset(offset)
            .onChange(of: [coordinate.latitude, coordinate.longitude]) { old, new in
                guard old.count == 2, new.count == 2,
                      let was = proxy.convert(.init(latitude: old[0], longitude: old[1]), to: .local),
                      let now = proxy.convert(.init(latitude: new[0], longitude: new[1]), to: .local)
                else { return }
                let back = CGSize(width: was.x - now.x, height: was.y - now.y)
                guard abs(back.width) <= Self.maxSlidePoints, abs(back.height) <= Self.maxSlidePoints else {
                    offset = .zero
                    return
                }
                var instantly = Transaction()
                instantly.disablesAnimations = true
                withTransaction(instantly) { offset = back }
                Task { @MainActor in
                    withAnimation(.linear(duration: Self.interval)) { offset = .zero }
                }
            }
    }
}
