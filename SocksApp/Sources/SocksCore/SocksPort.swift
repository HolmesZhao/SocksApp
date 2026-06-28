import Foundation

public enum SocksPort {
    public static func parse(_ text: String) -> UInt16? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = UInt32(trimmed), (1...65_535).contains(value) else {
            return nil
        }
        return UInt16(value)
    }
}
