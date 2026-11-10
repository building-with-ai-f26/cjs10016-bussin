import Foundation
import PostHog

enum Analytics {
    /// No-op unless a real key is present (Secrets.xcconfig → Info.plist).
    static func start() {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "PostHogApiKey") as? String,
              key.hasPrefix("phc_") else { return }
        let config = PostHogConfig(apiKey: key, host: "https://us.i.posthog.com")
        PostHogSDK.shared.setup(config)
        PostHogSDK.shared.capture("app_opened")
    }
}
