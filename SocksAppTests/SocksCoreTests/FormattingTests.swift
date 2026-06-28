import XCTest
@testable import SocksCore

final class FormattingTests: XCTestCase {
    func testByteFormatterUsesExpectedUnits() {
        XCTAssertEqual(ByteFormatter.formatBytes(0), "0 B")
        XCTAssertEqual(ByteFormatter.formatBytes(1_024), "1.0 KB")
        XCTAssertEqual(ByteFormatter.formatBytes(1_048_576), "1.0 MB")
        XCTAssertEqual(ByteFormatter.formatSpeed(1_536), "1.5 KB/s")
    }
}
