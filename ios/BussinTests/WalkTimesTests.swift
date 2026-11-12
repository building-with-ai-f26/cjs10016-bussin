import XCTest
import CoreLocation
@testable import Bussin

final class WalkTimesTests: XCTestCase {
    func testAFewStepsDoNotChangeTheCacheKeyButABlockDoes() {
        let stop = CLLocationCoordinate2D(latitude: 40.69430, longitude: -73.98650)
        let me = CLLocationCoordinate2D(latitude: 40.72951, longitude: -73.99651)
        let fewSteps = CLLocationCoordinate2D(latitude: 40.72953, longitude: -73.99653)      // ~3 m on
        let nextBlock = CLLocationCoordinate2D(latitude: 40.73050, longitude: -73.99651)     // ~110 m on
        XCTAssertEqual(WalkTimes.key(me, stop), WalkTimes.key(fewSteps, stop))
        XCTAssertNotEqual(WalkTimes.key(me, stop), WalkTimes.key(nextBlock, stop))
        XCTAssertNotEqual(WalkTimes.key(me, stop), WalkTimes.key(stop, me), "direction matters")
    }
}
