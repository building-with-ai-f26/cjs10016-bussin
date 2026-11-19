import ActivityKit
import Foundation
import UserNotifications

/// The lock screen card (a Live Activity) for a Go trip, plus a plain notification as a backup
/// for anyone who has Live Activities turned off. Both are local: nothing goes through a server.
@MainActor
final class GoLiveCard {
    private var activity: Activity<GoActivityAttributes>?
    private var lastState: GoActivityAttributes.ContentState?

    /// Asked the first time someone taps Go. The card itself needs no permission.
    func askForNotifications() {
        Task { _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) }
    }

    func start(_ attributes: GoActivityAttributes, _ state: GoActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        activity = try? Activity.request(attributes: attributes, content: content(state), pushType: nil)
        lastState = state
    }

    /// Redraws the card when something changed. With `alert`, the screen lights up and the phone
    /// buzzes. If there's no card to show it on, a notification does that job instead.
    func update(_ state: GoActivityAttributes.ContentState, alert: (title: String, body: String)? = nil) {
        if let alert, activity == nil { notify(alert.title, alert.body) }
        guard let activity, state != lastState || alert != nil else { return }
        lastState = state
        let config = alert.map {
            AlertConfiguration(title: LocalizedStringResource(stringLiteral: $0.title),
                               body: LocalizedStringResource(stringLiteral: $0.body), sound: .default)
        }
        Task { await activity.update(content(state), alertConfiguration: config) }
    }

    /// Takes the card down: right away when you end the trip, after a few minutes once you've arrived.
    func end(_ state: GoActivityAttributes.ContentState?, after seconds: TimeInterval = 0) {
        guard let activity else { return }
        self.activity = nil
        lastState = nil
        let policy: ActivityUIDismissalPolicy = seconds > 0 ? .after(.now.addingTimeInterval(seconds)) : .immediate
        Task { await activity.end(state.map(content), dismissalPolicy: policy) }
    }

    /// A card left over from a trip the app didn't get to finish (it was closed mid-trip).
    static func endLeftovers() {
        for leftover in Activity<GoActivityAttributes>.activities {
            Task { await leftover.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// Marked out of date if the app stops updating it for a few minutes.
    private func content(_ state: GoActivityAttributes.ContentState) -> ActivityContent<GoActivityAttributes.ContentState> {
        ActivityContent(state: state, staleDate: .now.addingTimeInterval(5 * 60))
    }

    private func notify(_ title: String, _ body: String) {
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = body
        c.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "go-\(title)", content: c, trigger: nil))
    }
}
