import SwiftUI

extension Color {
    /// "#f7b6d2" or "f7b6d2" → Color. Falls back to gray on junk.
    init(hex: String) {
        var h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
        let v = UInt64(h, radix: 16) ?? 0x8E8E93
        self.init(red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }

    /// Black or white text, whichever reads on the given background.
    static func textOn(hex: String) -> Color {
        var h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
        let v = UInt64(h, radix: 16) ?? 0x8E8E93
        let r = Double((v >> 16) & 0xFF), g = Double((v >> 8) & 0xFF), b = Double(v & 0xFF)
        let luma = (0.299 * r + 0.587 * g + 0.114 * b) / 255
        return luma > 0.6 ? .black : .white
    }
}
