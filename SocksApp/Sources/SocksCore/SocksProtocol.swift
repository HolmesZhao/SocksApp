import Foundation

#if canImport(Darwin)
import Darwin
#endif

public enum SocksCommand: UInt8, Sendable {
    case connect = 0x01
    case udpAssociate = 0x03
}

public struct SocksDestination: Equatable, Sendable {
    public let host: String
    public let port: UInt16
}

public struct SocksRequest: Equatable, Sendable {
    public let command: SocksCommand
    public let destination: SocksDestination
}

public enum SocksAuthenticationMode: Equatable, Sendable {
    case open
    case usernamePassword(username: String, password: String)
}

public enum SocksError: Error, Equatable, Sendable {
    case incomplete
    case generalFailure
    case commandNotSupported
    case addressTypeNotSupported
    case invalidVersion

    public var replyCode: UInt8 {
        switch self {
        case .incomplete, .generalFailure, .invalidVersion:
            return 0x01
        case .commandNotSupported:
            return 0x07
        case .addressTypeNotSupported:
            return 0x08
        }
    }
}

public enum SocksHandshake {
    public static func selectAuthenticationMethod(from data: Data, mode: SocksAuthenticationMode = .open) throws -> Data {
        guard data.count >= 2 else { throw SocksError.incomplete }
        guard data[0] == 0x05 else { throw SocksError.invalidVersion }

        let count = Int(data[1])
        guard data.count >= 2 + count else { throw SocksError.incomplete }

        let methods = data[2..<(2 + count)]
        let selected: UInt8
        switch mode {
        case .open:
            selected = methods.contains(0x00) ? 0x00 : 0xff
        case .usernamePassword:
            selected = methods.contains(0x02) ? 0x02 : 0xff
        }
        return Data([0x05, selected])
    }
}

public enum SocksUsernamePasswordAuthentication {
    public static func response(for data: Data, username: String, password: String) throws -> Data {
        guard data.count >= 2 else { throw SocksError.incomplete }
        guard data[0] == 0x01 else { throw SocksError.invalidVersion }

        let usernameLength = Int(data[1])
        guard data.count >= 2 + usernameLength + 1 else { throw SocksError.incomplete }
        let usernameStart = 2
        let usernameEnd = usernameStart + usernameLength
        let passwordLength = Int(data[usernameEnd])
        let passwordStart = usernameEnd + 1
        let passwordEnd = passwordStart + passwordLength
        guard data.count >= passwordEnd else { throw SocksError.incomplete }

        let receivedUsername = String(data: data[usernameStart..<usernameEnd], encoding: .utf8)
        let receivedPassword = String(data: data[passwordStart..<passwordEnd], encoding: .utf8)
        let isValid = receivedUsername == username && receivedPassword == password
        return Data([0x01, isValid ? 0x00 : 0x01])
    }

    public static func isSuccess(_ response: Data) -> Bool {
        response.count == 2 && response[1] == 0x00
    }
}

public enum SocksRequestParser {
    public static func parse(_ data: Data) throws -> SocksRequest {
        guard data.count >= 4 else { throw SocksError.incomplete }
        guard data[0] == 0x05 else { throw SocksError.invalidVersion }
        guard data[2] == 0x00 else { throw SocksError.generalFailure }
        guard let command = SocksCommand(rawValue: data[1]) else { throw SocksError.commandNotSupported }

        var cursor = 4
        let host: String
        switch data[3] {
        case 0x01:
            guard data.count >= cursor + 4 + 2 else { throw SocksError.incomplete }
            host = data[cursor..<(cursor + 4)].map(String.init).joined(separator: ".")
            cursor += 4
        case 0x03:
            guard data.count >= cursor + 1 else { throw SocksError.incomplete }
            let length = Int(data[cursor])
            cursor += 1
            guard data.count >= cursor + length + 2 else { throw SocksError.incomplete }
            guard let name = String(data: data[cursor..<(cursor + length)], encoding: .utf8) else {
                throw SocksError.generalFailure
            }
            host = name
            cursor += length
        case 0x04:
            guard data.count >= cursor + 16 + 2 else { throw SocksError.incomplete }
            host = ipv6String(from: data[cursor..<(cursor + 16)])
            cursor += 16
        default:
            throw SocksError.addressTypeNotSupported
        }

        let port = (UInt16(data[cursor]) << 8) | UInt16(data[cursor + 1])
        return SocksRequest(command: command, destination: SocksDestination(host: host, port: port))
    }

    private static func ipv6String(from bytes: Data.SubSequence) -> String {
        #if canImport(Darwin)
        var raw = Array(bytes)
        var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        raw.withUnsafeMutableBytes { pointer in
            _ = inet_ntop(AF_INET6, pointer.baseAddress, &buffer, socklen_t(INET6_ADDRSTRLEN))
        }
        return String(cString: buffer)
        #else
        return bytes.map { String(format: "%02x", $0) }.joined(separator: ":")
        #endif
    }
}

public enum SocksReply {
    public static func success() -> Data {
        success(host: "0.0.0.0", port: 0)
    }

    public static func success(host: String, port: UInt16) -> Data {
        var response = Data([0x05, 0x00, 0x00])
        let octets = host.split(separator: ".").compactMap { UInt8($0) }
        if octets.count == 4 {
            response.append(0x01)
            response.append(contentsOf: octets)
        } else {
            response.append(contentsOf: [0x01, 0, 0, 0, 0])
        }
        response.append(UInt8(port >> 8))
        response.append(UInt8(port & 0x00ff))
        return response
    }

    public static func failure(_ error: SocksError) -> Data {
        Data([0x05, error.replyCode, 0x00, 0x01, 0, 0, 0, 0, 0, 0])
    }
}
