import Foundation

#if canImport(Darwin)
import Darwin
#endif

public final class SocksUDPRelay: @unchecked Sendable {
    private let queue: DispatchQueue
    private let stats: TrafficStats
    private let log: @Sendable (String) -> Void
    private var socketFD: Int32 = -1
    private var readSource: DispatchSourceRead?
    private var clientAddress: sockaddr_storage?
    private var clientAddressLength: socklen_t = 0

    public init(queue: DispatchQueue, stats: TrafficStats, log: @escaping @Sendable (String) -> Void) {
        self.queue = queue
        self.stats = stats
        self.log = log
    }

    public func start() throws -> UInt16 {
        #if canImport(Darwin)
        socketFD = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard socketFD >= 0 else { throw SocksError.generalFailure }

        var reuse: Int32 = 1
        setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var bindAddress = sockaddr_in()
        bindAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        bindAddress.sin_family = sa_family_t(AF_INET)
        bindAddress.sin_port = 0
        bindAddress.sin_addr = in_addr(s_addr: INADDR_ANY.bigEndian)

        let bindResult = withUnsafePointer(to: &bindAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            stop()
            throw SocksError.generalFailure
        }

        var boundAddress = sockaddr_in()
        var boundLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(socketFD, $0, &boundLength)
            }
        }
        guard nameResult == 0 else {
            stop()
            throw SocksError.generalFailure
        }

        let source = DispatchSource.makeReadSource(fileDescriptor: socketFD, queue: queue)
        source.setEventHandler { [weak self] in
            self?.receive()
        }
        source.setCancelHandler { [fd = socketFD] in
            if fd >= 0 {
                close(fd)
            }
        }
        readSource = source
        source.resume()

        let port = UInt16(bigEndian: boundAddress.sin_port)
        log("[SOCKS] UDP relay listening on 0.0.0.0:\(port)")
        return port
        #else
        throw SocksError.commandNotSupported
        #endif
    }

    public func stop() {
        readSource?.cancel()
        readSource = nil
        socketFD = -1
    }

    private func receive() {
        #if canImport(Darwin)
        var buffer = [UInt8](repeating: 0, count: 65_535)
        var from = sockaddr_storage()
        var fromLength = socklen_t(MemoryLayout<sockaddr_storage>.size)
        let received = withUnsafeMutablePointer(to: &from) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                recvfrom(socketFD, &buffer, buffer.count, 0, sockaddrPointer, &fromLength)
            }
        }

        guard received > 0 else { return }
        let data = Data(buffer.prefix(Int(received)))

        if isCurrentClient(from, length: fromLength), let clientAddress {
            forwardClientDatagram(data, from: clientAddress, length: clientAddressLength)
            return
        }

        if clientAddress == nil, data.starts(with: [0x00, 0x00, 0x00]) {
            clientAddress = from
            clientAddressLength = fromLength
            forwardClientDatagram(data, from: from, length: fromLength)
            return
        }

        forwardRemoteResponse(data, from: from)
        #endif
    }

    private func forwardClientDatagram(_ data: Data, from clientAddress: sockaddr_storage, length: socklen_t) {
        do {
            let datagram = try SocksUDPDatagram.parse(data)
            guard let destination = resolveIPv4(host: datagram.destination.host, port: datagram.destination.port) else {
                log("[SOCKS] UDP resolve failed: \(datagram.destination.host):\(datagram.destination.port)")
                return
            }
            send(datagram.payload, to: destination.address, length: destination.length)
            stats.addUpload(datagram.payload.count)
        } catch {
            log("[SOCKS] UDP datagram rejected: \(error)")
        }
    }

    private func forwardRemoteResponse(_ data: Data, from remoteAddress: sockaddr_storage) {
        guard let clientAddress else { return }
        let source = destination(from: remoteAddress)
        let wrapped = SocksUDPDatagram.buildResponse(from: source, payload: data)
        send(wrapped, to: clientAddress, length: clientAddressLength)
        stats.addDownload(data.count)
    }

    private func isCurrentClient(_ address: sockaddr_storage, length: socklen_t) -> Bool {
        guard let clientAddress else { return false }
        return length == clientAddressLength && withUnsafeBytes(of: address) { left in
            withUnsafeBytes(of: clientAddress) { right in
                memcmp(left.baseAddress, right.baseAddress, Int(length)) == 0
            }
        }
    }

    private func send(_ data: Data, to address: sockaddr_storage, length: socklen_t) {
        var mutableAddress = address
        data.withUnsafeBytes { dataPointer in
            withUnsafePointer(to: &mutableAddress) { addressPointer in
                addressPointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    _ = sendto(socketFD, dataPointer.baseAddress, data.count, 0, $0, length)
                }
            }
        }
    }

    private func resolveIPv4(host: String, port: UInt16) -> (address: sockaddr_storage, length: socklen_t)? {
        #if canImport(Darwin)
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_DGRAM
        hints.ai_protocol = IPPROTO_UDP

        var result: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(host, String(port), &hints, &result)
        guard status == 0, let first = result else { return nil }
        defer { freeaddrinfo(result) }

        var storage = sockaddr_storage()
        memcpy(&storage, first.pointee.ai_addr, Int(first.pointee.ai_addrlen))
        return (storage, first.pointee.ai_addrlen)
        #else
        return nil
        #endif
    }

    private func destination(from address: sockaddr_storage) -> SocksDestination {
        #if canImport(Darwin)
        if address.ss_family == sa_family_t(AF_INET) {
            var ipv4 = address
            return withUnsafePointer(to: &ipv4) { pointer in
                pointer.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { ipv4Pointer in
                    var addr = ipv4Pointer.pointee.sin_addr
                    var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                    let host = inet_ntop(AF_INET, &addr, &buffer, socklen_t(INET_ADDRSTRLEN)).map(String.init(cString:)) ?? "0.0.0.0"
                    return SocksDestination(host: host, port: UInt16(bigEndian: ipv4Pointer.pointee.sin_port))
                }
            }
        }
        #endif
        return SocksDestination(host: "0.0.0.0", port: 0)
    }
}
