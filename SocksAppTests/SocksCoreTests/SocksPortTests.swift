import XCTest
@testable import SocksCore

final class SocksPortTests: XCTestCase {
    func testParsesValidPortText() {
        XCTAssertEqual(SocksPort.parse("1080"), 1_080)
        XCTAssertEqual(SocksPort.parse(" 9876 "), 9_876)
        XCTAssertEqual(SocksPort.parse("65535"), 65_535)
    }

    func testRejectsInvalidPortText() {
        XCTAssertNil(SocksPort.parse(""))
        XCTAssertNil(SocksPort.parse("0"))
        XCTAssertNil(SocksPort.parse("65536"))
        XCTAssertNil(SocksPort.parse("abc"))
    }
}
