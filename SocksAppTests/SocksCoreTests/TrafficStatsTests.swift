import XCTest
@testable import SocksCore

final class TrafficStatsTests: XCTestCase {
    func testSnapshotCalculatesDirectionalSpeeds() {
        let stats = TrafficStats()
        stats.addUpload(1_000)
        stats.addDownload(3_000)
        _ = stats.snapshot(now: Date(timeIntervalSince1970: 1))

        stats.addUpload(2_000)
        stats.addDownload(1_000)
        let snapshot = stats.snapshot(now: Date(timeIntervalSince1970: 3))

        XCTAssertEqual(snapshot.uploadBytes, 3_000)
        XCTAssertEqual(snapshot.downloadBytes, 4_000)
        XCTAssertEqual(snapshot.uploadBytesPerSecond, 1_000)
        XCTAssertEqual(snapshot.downloadBytesPerSecond, 500)
    }
}
