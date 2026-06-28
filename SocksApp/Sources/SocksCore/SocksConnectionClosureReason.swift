public enum SocksConnectionClosureReason: Equatable, Sendable {
    case closedNormally(String)
    case failed(String)
    case rejected(String)

    public var logMessage: String {
        switch self {
        case .closedNormally(let detail):
            return "[SOCKS] Client connection closed normally: \(detail)"
        case .failed(let detail):
            return "[SOCKS] Client connection failed: \(detail)"
        case .rejected(let detail):
            return "[SOCKS] Client connection rejected: \(detail)"
        }
    }
}
