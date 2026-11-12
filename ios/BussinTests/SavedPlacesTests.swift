import XCTest
@testable import Bussin

@MainActor
final class SavedPlacesTests: XCTestCase {
    private var defaults: UserDefaults!
    override func setUp() {
        defaults = UserDefaults(suiteName: "SavedPlacesTests")
        defaults.removePersistentDomain(forName: "SavedPlacesTests")
    }

    private func place(_ name: String) -> Destination {
        Destination(name: name, subtitle: "New York", latitude: 40.73, longitude: -73.99)
    }

    func testFavoritesToggleAndSurviveRelaunch() {
        let saved = SavedPlaces(defaults: defaults)
        saved.toggleFavorite(place("Tandon"))
        XCTAssertTrue(saved.isFavorite(place("Tandon")))
        XCTAssertEqual(SavedPlaces(defaults: defaults).favorites.map(\.name), ["Tandon"])
        saved.toggleFavorite(place("Tandon"))
        XCTAssertTrue(SavedPlaces(defaults: defaults).favorites.isEmpty)
    }

    func testHomeRecentsAreTheTwoNewestNonFavorites() {
        let saved = SavedPlaces(defaults: defaults)
        ["Joe's Pizza", "Bobst", "Tandon", "Palladium"].forEach { saved.noteSearched(place($0)) }
        saved.toggleFavorite(place("Palladium"))
        XCTAssertEqual(saved.homeRecents.map(\.name), ["Tandon", "Bobst"])
    }

    func testSearchingAgainMovesAPlaceToTheFrontWithoutDuplicating() {
        let saved = SavedPlaces(defaults: defaults)
        ["Bobst", "Tandon", "Bobst"].forEach { saved.noteSearched(place($0)) }
        XCTAssertEqual(saved.recents.map(\.name), ["Bobst", "Tandon"])
    }

    func testRecentsAreCapped() {
        let saved = SavedPlaces(defaults: defaults)
        (1...15).forEach { saved.noteSearched(place("Place \($0)")) }
        XCTAssertEqual(saved.recents.count, SavedPlaces.maxRecents)
        XCTAssertEqual(saved.recents.first?.name, "Place 15")
    }
}
