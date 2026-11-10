import XCTest
@testable import Bussin

@MainActor
final class ShuttleStoreTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    private struct FakeAPI: PassioFetching {
        let stops: Data
        let buses: Data
        func stopsData() async throws -> Data { stops }
        func busesData() async throws -> Data { buses }
    }

    private struct FailingAPI: PassioFetching {
        func stopsData() async throws -> Data { throw URLError(.notConnectedToInternet) }
        func busesData() async throws -> Data { throw URLError(.notConnectedToInternet) }
    }

    func testRefreshAndPollFillTheStore() async throws {
        let store = ShuttleStore(api: FakeAPI(stops: try fixture("stops"), buses: try fixture("buses")))
        await store.refreshCatalog()
        XCTAssertEqual(store.routes.count, 7)
        XCTAssertFalse(store.stops.isEmpty)

        await store.pollOnce()
        XCTAssertFalse(store.buses.isEmpty)
        XCTAssertEqual(store.feedState, .live)
        XCTAssertNotNil(store.route(for: store.buses[0].routeId))
    }

    func testBadCatalogDataKeepsOldCatalog() async throws {
        let store = ShuttleStore(api: FakeAPI(stops: try fixture("stops"), buses: try fixture("buses")))
        await store.refreshCatalog()
        store.apply(catalogData: Data("<html>gateway error</html>".utf8))
        XCTAssertEqual(store.routes.count, 7, "garbage from the feed must not wipe a good catalog")
    }

    func testFeedFailureEventuallyMarksStale() async throws {
        let store = ShuttleStore(api: FailingAPI())
        store.staleAfter = 0                      // don't wait 30 real seconds in a test
        store.apply(catalogData: try fixture("stops"))
        store.apply(busesData: try fixture("buses"))
        XCTAssertEqual(store.feedState, .live)

        await store.pollOnce()                    // fails; lastBusUpdate is now "too old"
        guard case .stale = store.feedState else {
            return XCTFail("expected stale, got \(store.feedState)")
        }
        XCTAssertFalse(store.buses.isEmpty, "stale keeps last known buses on the map")
    }
}
