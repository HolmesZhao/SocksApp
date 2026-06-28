import Foundation

public struct LogEntry: Identifiable, Equatable, Sendable {
    public enum Level: Sendable {
        case info
        case success
        case error
        case disconnect

        public init(message: String) {
            if message.contains("Error") || message.contains("Failed") || message.contains("failed") {
                self = .error
            } else if message.contains("disconnected") {
                self = .disconnect
            } else if message.contains("connected") || message.contains("Successfully") {
                self = .success
            } else {
                self = .info
            }
        }
    }

    public let id: UUID
    public let date: Date
    public let message: String
    public let level: Level

    public init(id: UUID = UUID(), date: Date = Date(), message: String) {
        self.id = id
        self.date = date
        self.message = message
        self.level = Level(message: message)
    }
}

public final class LogStore: @unchecked Sendable {
    private let maxLines: Int
    private let lock = NSLock()
    private var storage: [LogEntry] = []

    public init(maxLines: Int = 1_000) {
        self.maxLines = max(1, maxLines)
    }

    public var entries: [LogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    @discardableResult
    public func append(_ message: String, date: Date = Date()) -> LogEntry {
        let entry = LogEntry(date: date, message: message)
        lock.lock()
        storage.append(entry)
        if storage.count > maxLines {
            storage.removeFirst(storage.count - maxLines)
        }
        lock.unlock()
        return entry
    }
}
