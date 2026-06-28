import Foundation

public enum ByteFormatter {
    public static func formatBytes(_ bytes: UInt64) -> String {
        if bytes < 1_024 { return "\(bytes) B" }
        if bytes < 1_024 * 1_024 { return String(format: "%.1f KB", Double(bytes) / 1_024.0) }
        if bytes < 1_024 * 1_024 * 1_024 { return String(format: "%.1f MB", Double(bytes) / (1_024.0 * 1_024.0)) }
        return String(format: "%.1f GB", Double(bytes) / (1_024.0 * 1_024.0 * 1_024.0))
    }

    public static func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1_024 { return String(format: "%.0f B/s", bytesPerSecond) }
        if bytesPerSecond < 1_024 * 1_024 { return String(format: "%.1f KB/s", bytesPerSecond / 1_024.0) }
        if bytesPerSecond < 1_024 * 1_024 * 1_024 { return String(format: "%.1f MB/s", bytesPerSecond / (1_024.0 * 1_024.0)) }
        return String(format: "%.1f GB/s", bytesPerSecond / (1_024.0 * 1_024.0 * 1_024.0))
    }
}
