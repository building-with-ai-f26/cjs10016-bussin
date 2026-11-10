import XCTest
@testable import Bussin

final class PassioAPITests: XCTestCase {
    func testFormBodyPercentEncodesJSON() {
        let body = PassioAPI.formBody(json: #"{"s0":"1007","sA":1}"#)
        let s = String(decoding: body, as: UTF8.self)
        XCTAssertTrue(s.hasPrefix("json="))
        XCTAssertFalse(s.contains("{"), "braces must be percent-encoded")
        XCTAssertFalse(s.contains("\""), "quotes must be percent-encoded")
        XCTAssertTrue(s.contains("1007"))
    }

    func testEndpointURLs() {
        XCTAssertEqual(PassioAPI.url(query: "getBuses=2").absoluteString,
                       "https://passio3.com/www/mapGetData.php?getBuses=2")
    }
}
