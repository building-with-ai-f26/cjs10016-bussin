import Foundation

/// What, if anything, Home should say about service as a whole.
enum ServiceStatus: Equatable {
    case nothingRunning     // the feed works and reports no shuttles out
    case feedDown           // we can't reach the feed, so we don't know

    @MainActor
    static func notice(feed: ShuttleStore.FeedState, busCount: Int) -> ServiceStatus? {
        switch feed {
        case .loading: return nil
        case .stale: return .feedDown
        case .live: return busCount == 0 ? .nothingRunning : nil
        }
    }

    var icon: String {
        switch self {
        case .nothingRunning: return "moon.zzz.fill"
        case .feedDown: return "wifi.slash"
        }
    }

    var title: String {
        switch self {
        case .nothingRunning: return "No shuttles are running right now"
        case .feedDown: return "Can't reach live bus data"
        }
    }

    var detail: String {
        switch self {
        case .nothingRunning: return "Routes and stops are still here. Buses appear when service starts."
        case .feedDown: return "Check your connection. Bussin keeps trying and shows the last buses it saw."
        }
    }
}
