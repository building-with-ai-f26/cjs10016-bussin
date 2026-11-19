import ActivityKit
import SwiftUI
import WidgetKit

@main
struct BussinWidgets: WidgetBundle {
    var body: some Widget { GoLiveActivity() }
}

/// The small card on the lock screen and in the Dynamic Island while a Go trip runs.
struct GoLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GoActivityAttributes.self) { context in
            LockScreenCard(attributes: context.attributes, state: context.state)
                .padding(16)
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            let a = context.attributes, s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Badge(letter: a.routeLetter, colorHex: a.routeColorHex, size: 36)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let m = s.minutes { MinutesView(minutes: m) }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.title).font(.headline).foregroundStyle(s.getOffNext ? Color.yellow : Color.primary)
                        Text(s.detail).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Badge(letter: a.routeLetter, colorHex: a.routeColorHex, size: 22)
            } compactTrailing: {
                Text(compactText(s)).font(.caption.weight(.semibold))
                    .foregroundStyle(s.getOffNext ? Color.yellow : Color.primary)
            } minimal: {
                Badge(letter: a.routeLetter, colorHex: a.routeColorHex, size: 22)
            }
        }
    }

    /// A few characters for the right side of the island: what matters most right now.
    private func compactText(_ s: GoActivityAttributes.ContentState) -> String {
        if s.getOffNext { return "Next stop" }
        if let left = s.stopsLeft { return "\(left) \(left == 1 ? "stop" : "stops")" }
        if let m = s.minutes { return m < 1 ? "Now" : "\(m) min" }
        return s.leg >= 3 ? "Done" : "Go"
    }
}

private struct LockScreenCard: View {
    let attributes: GoActivityAttributes
    let state: GoActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            Badge(letter: attributes.routeLetter, colorHex: attributes.routeColorHex, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(state.title)
                    .font(.headline)
                    .foregroundStyle(state.getOffNext ? Color.orange : Color.primary)
                Text(state.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                LegDots(current: state.leg).padding(.top, 2)
            }
            Spacer(minLength: 0)
            if let m = state.minutes { MinutesView(minutes: m) }
        }
    }
}

/// Three dots for walk, ride, walk; the current one is wider.
private struct LegDots: View {
    let current: Int
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(i <= current ? Color.primary : Color.secondary.opacity(0.4))
                    .frame(width: i == current ? 18 : 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct MinutesView: View {
    let minutes: Int
    var body: some View {
        VStack(spacing: 0) {
            Text(minutes < 1 ? "Now" : "\(minutes)").font(.title2.weight(.bold)).monospacedDigit()
            if minutes >= 1 { Text("min").font(.caption).foregroundStyle(.secondary) }
        }
    }
}

private struct Badge: View {
    let letter: String
    let colorHex: String
    let size: CGFloat
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(Color(hex: colorHex))
            .frame(width: size, height: size)
            .overlay(Text(letter).font(.system(size: size * 0.53, weight: .bold))
                .foregroundStyle(Color.textOn(hex: colorHex)))
            .accessibilityLabel("Route \(letter)")
    }
}
