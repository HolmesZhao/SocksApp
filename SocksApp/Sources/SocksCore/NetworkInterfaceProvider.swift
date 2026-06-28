import Foundation

#if canImport(Darwin)
import Darwin
#endif

public enum NetworkInterfaceProvider {
    public static func deviceIPAddress(logger: ((String) -> Void)? = nil) -> String {
        logger?("[SOCKS] Starting IP address detection")

        #if canImport(Darwin)
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0 else {
            logger?("[SOCKS] Failed to get network interfaces")
            return "127.0.0.1"
        }
        defer { freeifaddrs(interfaces) }

        logger?("[SOCKS] Successfully retrieved network interfaces")
        var address = "127.0.0.1"
        var cursor = interfaces

        while let current = cursor?.pointee {
            defer { cursor = current.ifa_next }
            guard let socketAddress = current.ifa_addr, socketAddress.pointee.sa_family == UInt8(AF_INET) else {
                continue
            }

            let interfaceName = String(cString: current.ifa_name)
            logger?("[SOCKS] Checking interface: \(interfaceName)")
            guard interfaceName == "bridge100" || interfaceName == "en0" else {
                continue
            }

            var ipv4 = socketAddress.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
            var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            if let cString = inet_ntop(AF_INET, &ipv4, &buffer, socklen_t(INET_ADDRSTRLEN)) {
                address = String(cString: cString)
                logger?("[SOCKS] Found IP address: \(address)")
            }
        }

        if address == "127.0.0.1" {
            logger?("[SOCKS] No matching interface found")
        }
        return address
        #else
        logger?("[SOCKS] Network interface detection is unavailable on this platform")
        return "127.0.0.1"
        #endif
    }
}
