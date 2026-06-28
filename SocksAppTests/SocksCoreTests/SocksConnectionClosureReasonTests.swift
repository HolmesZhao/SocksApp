import XCTest
@testable import SocksCore

final class SocksConnectionClosureReasonTests: XCTestCase {
    func testNormalClosureUsesNonFailureMessage() {
        let reason = SocksConnectionClosureReason.closedNormally("client finished request")

        XCTAssertEqual(reason.logMessage, "[SOCKS] Client connection closed normally: client finished request")
        XCTAssertFalse(reason.logMessage.contains("failed"))
        XCTAssertFalse(reason.logMessage.contains("disconnected"))
    }

    func testFailureClosureUsesFailureMessage() {
        let reason = SocksConnectionClosureReason.failed("Download forwarding failed: socket closed")

        XCTAssertEqual(reason.logMessage, "[SOCKS] Client connection failed: Download forwarding failed: socket closed")
    }

    func testRejectedClosureUsesRejectedMessage() {
        let reason = SocksConnectionClosureReason.rejected("No supported authentication method")

        XCTAssertEqual(reason.logMessage, "[SOCKS] Client connection rejected: No supported authentication method")
    }
}
