import SwiftUI

/// Shown once, the first time Bussin opens: what the app does and why it asks for location.
struct WelcomeView: View {
    let onContinue: () -> Void

    private struct Feature: Identifiable {
        let icon: String, tint: Color, title: String, detail: String
        var id: String { title }
    }

    private let features = [
        Feature(icon: "bus.fill", tint: .blue, title: "See every shuttle live",
                detail: "Buses move on the map as they drive, with arrival times for each stop."),
        Feature(icon: "figure.walk", tint: .green, title: "Ride or walk?",
                detail: "Search any place and Bussin tells you which is faster right now."),
        Feature(icon: "star.fill", tint: .yellow, title: "Keep your places",
                detail: "Star where you go most and it waits on the home screen."),
        Feature(icon: "location.fill", tint: .blue, title: "Why it asks for your location",
                detail: "To find your nearest stop and time your walk. Bussin never collects it."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 24)
            Text("Bussin").font(.largeTitle.bold())
            Text("NYU's free shuttles, live.")
                .font(.title3).foregroundStyle(.secondary)
                .padding(.bottom, 32)

            VStack(alignment: .leading, spacing: 24) {
                ForEach(features) { f in
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: f.icon)
                            .font(.title2).foregroundStyle(f.tint)
                            .frame(width: RowMetrics.iconColumn)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.title).font(.headline)
                            Text(f.detail).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            Spacer(minLength: 24)
            Button(action: onContinue) {
                Text("Continue").font(.headline).frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            Text("Not an official NYU app. Bus positions come from NYU's Passio GO feed.")
                .font(.footnote).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
        }
        .padding(24)
        .background(.background)
    }
}

#Preview { WelcomeView(onContinue: {}) }
