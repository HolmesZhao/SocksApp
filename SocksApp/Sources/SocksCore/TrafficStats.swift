import Foundation

public struct TrafficSnapshot: Equatable, Sendable {
    public let uploadBytes: UInt64
    public let downloadBytes: UInt64
    public let uploadBytesPerSecond: Double
    public let downloadBytesPerSecond: Double
}

public final class TrafficStats: @unchecked Sendable {
    private let lock = NSLock()
    private var uploadBytes: UInt64 = 0
    private var downloadBytes: UInt64 = 0
    private var lastUploadBytes: UInt64 = 0
    private var lastDownloadBytes: UInt64 = 0
    private var lastSnapshotDate: Date?

    public init() {}

    public func addUpload(_ bytes: Int) {
        guard bytes > 0 else { return }
        lock.lock()
        uploadBytes += UInt64(bytes)
        lock.unlock()
    }

    public func addDownload(_ bytes: Int) {
        guard bytes > 0 else { return }
        lock.lock()
        downloadBytes += UInt64(bytes)
        lock.unlock()
    }

    public func snapshot(now: Date = Date()) -> TrafficSnapshot {
        lock.lock()
        defer { lock.unlock() }

        let elapsed = lastSnapshotDate.map { max(now.timeIntervalSince($0), 0.001) }
        let uploadSpeed = elapsed.map { Double(uploadBytes - lastUploadBytes) / $0 } ?? 0
        let downloadSpeed = elapsed.map { Double(downloadBytes - lastDownloadBytes) / $0 } ?? 0

        lastUploadBytes = uploadBytes
        lastDownloadBytes = downloadBytes
        lastSnapshotDate = now

        return TrafficSnapshot(
            uploadBytes: uploadBytes,
            downloadBytes: downloadBytes,
            uploadBytesPerSecond: uploadSpeed,
            downloadBytesPerSecond: downloadSpeed
        )
    }
}
