import SwiftUI

/// Where the sheet's navigation can go. Also tells the map what to focus on.
enum Place: Hashable {
    case stop(String)
    case route(String)
    case bus(Int)
}

/// Rounded square in the route's feed color with its letter (DESIGN.md: Route Badge).
struct RouteBadge: View {
    let letter: String
    let colorHex: String
    var size: CGFloat = 30

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(Color(hex: colorHex))
            .frame(width: size, height: size)
            .overlay(
                Text(letter)
                    .font(.system(size: size * 0.53, weight: .bold))
                    .foregroundStyle(Color.textOn(hex: colorHex))
            )
            .accessibilityLabel("Route \(letter)")
    }
}

/// Green live-data text with the radio-wave mark. Green means live, nothing else.
struct LiveLabel: View {
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "dot.radiowaves.up.forward")
                .font(.caption2.weight(.bold))
                .symbolEffect(.variableColor.iterative, options: .repeating)
            Text(text)
        }
        .font(.headline)
        .foregroundStyle(.green)
    }
}

/// One departure: badge, route name, right-aligned live ETA.
struct DepartureRow: View {
    let route: ShuttleRoute
    let next: Double?
    let then: Double?

    var body: some View {
        HStack(spacing: 12) {
            RouteBadge(letter: route.letter, colorHex: route.colorHex)
            Text(route.name).font(.headline)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                if let next { LiveLabel(text: Fmt.eta(next)) }
                if let then {
                    Text("then \(Fmt.minutes(then))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
