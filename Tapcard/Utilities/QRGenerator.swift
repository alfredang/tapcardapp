import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

/// Generates a crisp QR code image for a card's public URL.
enum QRGenerator {
    private static let context = CIContext()

    /// `correctionLevel` "H" leaves room for a logo over the centre.
    static func image(for string: String, scale: CGFloat = 12,
                      correctionLevel: String = "M") -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = correctionLevel
        guard let output = filter.outputImage else { return nil }
        let transformed = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cg = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

extension Color {
    /// Build a Color from a `#RRGGBB` (or `#RGB`) hex string.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b: Double
        if cleaned.count == 3 {
            r = Double((value >> 8) & 0xF) / 15
            g = Double((value >> 4) & 0xF) / 15
            b = Double(value & 0xF) / 15
        } else {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        }
        self.init(red: r, green: g, blue: b)
    }

    /// Whether dark text reads better than white on this colour (relative
    /// luminance above ~0.55) — for colours the owner picks freely on the web.
    static func isLight(hex: String) -> Bool {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return false }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        return 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.55
    }
}
