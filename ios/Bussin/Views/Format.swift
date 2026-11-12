import Foundation

enum Fmt {
    /// "Now" under 45 s, else "3 min".
    static func eta(_ seconds: Double) -> String {
        seconds < 45 ? "Now" : "\(Int((seconds / 60).rounded())) min"
    }

    static func minutes(_ seconds: Double) -> String {
        "\(max(1, Int((seconds / 60).rounded()))) min"
    }

    private static let clockFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f
    }()

    static func clock(_ date: Date) -> String { clockFormatter.string(from: date) }
}
