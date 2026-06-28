import XCTest
@testable import SocksCore

final class SocksUDPDatagramTests: XCTestCase {
    func testParsesDomainDatagramWithoutFragmentation() throws {
        let packet = Data([0x00, 0x00, 0x00, 0x03, 0x0b])
            + Data("example.com".utf8)
            + Data([0x00, 0x35])
            + Data([0xde, 0xad])

        let datagram = try SocksUDPDatagram.parse(packet)

        XCTAssertEqual(datagram.destination.host, "example.com")
        XCTAssertEqual(datagram.destination.port, 53)
        XCTAssertEqual(Array(datagram.payload), [0xde, 0xad])
    }

    func testRejectsFragmentedUDPDatagram() {
        let packet = Data([0x00, 0x00, 0x01, 0x01, 127, 0, 0, 1, 0x00, 0x35])

        XCTAssertThrowsError(try SocksUDPDatagram.parse(packet)) { error in
            XCTAssertEqual(error as? SocksError, .generalFailure)
        }
    }

    func testBuildsIPv4DatagramResponse() {
        let packet = SocksUDPDatagram.buildResponse(
            from: SocksDestination(host: "8.8.8.8", port: 53),
            payload: Data([0xbe, 0xef])
        )

        XCTAssertEqual(Array(packet), [0, 0, 0, 1, 8, 8, 8, 8, 0, 53, 0xbe, 0xef])
    }
}
