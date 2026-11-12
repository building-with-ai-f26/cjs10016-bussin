import Foundation
import Observation

/// Favorites and recent searches. Lives on the phone only (UserDefaults); nothing is uploaded.
@Observable @MainActor
final class SavedPlaces {
    static let maxRecents = 10
    private(set) var favorites: [Destination]
    private(set) var recents: [Destination]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        favorites = Self.load("favorites", defaults)
        recents = Self.load("recents", defaults)
    }

    func isFavorite(_ d: Destination) -> Bool { favorites.contains(d) }

    func toggleFavorite(_ d: Destination) {
        if let i = favorites.firstIndex(of: d) { favorites.remove(at: i) } else { favorites.append(d) }
        save("favorites", favorites)
    }

    func noteSearched(_ d: Destination) {
        recents.removeAll { $0 == d }
        recents.insert(d, at: 0)
        recents = Array(recents.prefix(Self.maxRecents))
        save("recents", recents)
    }

    /// What Home shows under the favorites.
    var homeRecents: [Destination] { Array(recents.filter { !favorites.contains($0) }.prefix(2)) }

    private static func load(_ key: String, _ defaults: UserDefaults) -> [Destination] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Destination].self, from: data)) ?? []
    }

    private func save(_ key: String, _ value: [Destination]) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }
}
