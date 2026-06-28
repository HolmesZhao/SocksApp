import XCTest
@testable import SocksCore

final class LogStoreTests: XCTestCase {
    func testLogStoreKeepsNewestEntriesOnly() {
        let store = LogStore(maxLines: 3)

        store.append("[SOCKS] one")
        store.append("[SOCKS] two")
        store.append("[SOCKS] three")
        store.append("[SOCKS] four")

        XCTAssertEqual(store.entries.map(\.message), ["[SOCKS] two", "[SOCKS] three", "[SOCKS] four"])
    }

    func testLogLevelMatchesMessageContent() {
        XCTAssertEqual(LogEntry.Level(message: "Successfully connected"), .success)
        XCTAssertEqual(LogEntry.Level(message: "Failed to connect"), .error)
        XCTAssertEqual(LogEntry.Level(message: "client disconnected"), .disconnect)
        XCTAssertEqual(LogEntry.Level(message: "Listening"), .info)
    }
}
