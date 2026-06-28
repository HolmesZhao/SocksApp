import XCTest
@testable import SocksCore

final class SocksRequestParserTests: XCTestCase {
    func testSelectsNoAuthenticationWhenClientOffersIt() throws {
        let response = try SocksHandshake.selectAuthenticationMethod(from: Data([0x05, 0x01, 0x00]))
        XCTAssertEqual(Array(response), [0x05, 0x00])
    }

    func testRejectsAuthenticationWhenNoAuthIsNotOffered() throws {
        let response = try SocksHandshake.selectAuthenticationMethod(from: Data([0x05, 0x01, 0x02]))
        XCTAssertEqual(Array(response), [0x05, 0xff])
    }

    func testAuthenticationRequiredSelectsUsernamePassword() throws {
        let response = try SocksHandshake.selectAuthenticationMethod(
            from: Data([0x05, 0x02, 0x00, 0x02]),
            mode: .usernamePassword(username: "socks", password: "TOKEN123")
        )

        XCTAssertEqual(Array(response), [0x05, 0x02])
    }

    func testAuthenticationRequiredRejectsNoAuthOnlyClient() throws {
        let response = try SocksHandshake.selectAuthenticationMethod(
            from: Data([0x05, 0x01, 0x00]),
            mode: .usernamePassword(username: "socks", password: "TOKEN123")
        )

        XCTAssertEqual(Array(response), [0x05, 0xff])
    }

    func testOpenAuthenticationModeAllowsNoAuth() throws {
        let response = try SocksHandshake.selectAuthenticationMethod(
            from: Data([0x05, 0x01, 0x00]),
            mode: .open
        )

        XCTAssertEqual(Array(response), [0x05, 0x00])
    }

    func testUsernamePasswordAuthenticationValidatesCredentials() throws {
        let packet = Data([0x01, 0x05])
            + Data("socks".utf8)
            + Data([0x08])
            + Data("TOKEN123".utf8)

        let response = try SocksUsernamePasswordAuthentication.response(
            for: packet,
            username: "socks",
            password: "TOKEN123"
        )

        XCTAssertEqual(Array(response), [0x01, 0x00])
    }

    func testUsernamePasswordAuthenticationRejectsBadCredentials() throws {
        let packet = Data([0x01, 0x05])
            + Data("socks".utf8)
            + Data([0x03])
            + Data("bad".utf8)

        let response = try SocksUsernamePasswordAuthentication.response(
            for: packet,
            username: "socks",
            password: "TOKEN123"
        )

        XCTAssertEqual(Array(response), [0x01, 0x01])
    }

    func testParsesConnectRequestWithDomainName() throws {
        let request = Data([0x05, 0x01, 0x00, 0x03, 0x0b])
            + Data("example.com".utf8)
            + Data([0x01, 0xbb])

        let parsed = try SocksRequestParser.parse(request)

        XCTAssertEqual(parsed.command, .connect)
        XCTAssertEqual(parsed.destination.host, "example.com")
        XCTAssertEqual(parsed.destination.port, 443)
    }

    func testParsesUdpAssociateWithIPv4Address() throws {
        let request = Data([0x05, 0x03, 0x00, 0x01, 192, 168, 2, 11, 0x26, 0x94])

        let parsed = try SocksRequestParser.parse(request)

        XCTAssertEqual(parsed.command, .udpAssociate)
        XCTAssertEqual(parsed.destination.host, "192.168.2.11")
        XCTAssertEqual(parsed.destination.port, 9876)
    }

    func testReturnsSocksReplyCodesForUnsupportedCommandAndAddressType() {
        XCTAssertEqual(SocksError.commandNotSupported.replyCode, 0x07)
        XCTAssertEqual(SocksError.addressTypeNotSupported.replyCode, 0x08)
    }
}
