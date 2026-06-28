import Foundation

public struct SocksUDPDatagram: Equatable, Sendable {
    public let destination: SocksDestination
    public let payload: Data

    public static func parse(_ data: Data) throws -> SocksUDPDatagram {
        guard data.count >= 4 else { throw SocksError.incomplete }
        guard data[0] == 0x00, data[1] == 0x00 else { throw SocksError.generalFailure }
        guard data[2] == 0x00 else { throw SocksError.generalFailure }

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
        default:
            throw SocksError.addressTypeNotSupported
        }

        let port = (UInt16(data[cursor]) << 8) | UInt16(data[cursor + 1])
        cursor += 2
        return SocksUDPDatagram(
            destination: SocksDestination(host: host, port: port),
            payload: data[cursor...]
        )
    }

    public static func buildResponse(from source: SocksDestination, payload: Data) -> Data {
        var packet = Data([0x00, 0x00, 0x00])
        let octets = source.host.split(separator: ".").compactMap { UInt8($0) }
        if octets.count == 4 {
            packet.append(0x01)
            packet.append(contentsOf: octets)
        } else {
            let hostData = Data(source.host.utf8)
            packet.append(0x03)
            packet.append(UInt8(min(hostData.count, 255)))
            packet.append(hostData.prefix(255))
        }
        packet.append(UInt8(source.port >> 8))
        packet.append(UInt8(source.port & 0x00ff))
        packet.append(payload)
        return packet
    }
}
