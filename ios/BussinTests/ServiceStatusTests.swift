import XCTest
@testable import Bussin

@MainActor
final class ServiceStatusTests: XCTestCase {
    func testQuietWhenBusesAreOut() {
        XCTAssertNil(ServiceStatus.notice(feed: .live, busCount: 3))
    }

    func testSaysNothingIsRunningWhenTheFeedIsLiveButEmpty() {
        XCTAssertEqual(ServiceStatus.notice(feed: .live, busCount: 0), .nothingRunning)
    }

    func testStaysQuietWhileTheFirstUpdateLoads() {
        XCTAssertNil(ServiceStatus.notice(feed: .loading, busCount: 0), "don't claim nothing is running before we know")
    }

    func testAFeedProblemIsNotTheSameAsNoService() {
        XCTAssertEqual(ServiceStatus.notice(feed: .stale("x"), busCount: 0), .feedDown)
        XCTAssertEqual(ServiceStatus.notice(feed: .stale("x"), busCount: 4), .feedDown)
    }

    func testTheFeedGoingDownCountsOnceNotOnEveryPoll() {
        XCTAssertTrue(ServiceStatus.feedJustWentDown(from: .live, to: .stale("x")))
        XCTAssertTrue(ServiceStatus.feedJustWentDown(from: .loading, to: .stale("x")))
        XCTAssertFalse(ServiceStatus.feedJustWentDown(from: .stale("x"), to: .stale("y")), "still down, already counted")
        XCTAssertFalse(ServiceStatus.feedJustWentDown(from: .stale("x"), to: .live))
        XCTAssertFalse(ServiceStatus.feedJustWentDown(from: .live, to: .live))
    }
}
