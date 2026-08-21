import Foundation
import SwiftUI

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Color+Hex

/// Konvertiert zwischen SwiftUI-`Color` und RGB-Hexwerten.
///
/// Die Implementierung bleibt plattformneutral, damit PasukiUI sowohl in
/// iOS- als auch in macOS-Projekten verwendet werden kann.
public extension Color {

    // MARK: - Hex zu Farbe

    /// Erzeugt eine Farbe aus `#RRGGBB` oder `RRGGBB`.
    /// Ungültige Werte werden als Blau dargestellt.
    init(hexString: String) {
        let cleanedHex = hexString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard cleanedHex.count == 6,
              let value = UInt64(cleanedHex, radix: 16) else {
            self = .blue
            return
        }

        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    // MARK: - Farbe zu Hex

    /// Gibt die RGB-Komponenten als `#RRGGBB` zurück.
    func toHex() -> String? {
        guard let components = pasukiRGBComponents else { return nil }

        return String(
            format: "#%02X%02X%02X",
            Self.pasukiHexComponent(components.red),
            Self.pasukiHexComponent(components.green),
            Self.pasukiHexComponent(components.blue)
        )
    }

    // MARK: - Plattformadapter

    private var pasukiRGBComponents: (red: CGFloat, green: CGFloat, blue: CGFloat)? {
#if canImport(UIKit)
        let nativeColor = UIColor(self).resolvedColor(with: .current)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard nativeColor.getRed(
            &red,
            green: &green,
            blue: &blue,
            alpha: &alpha
        ) else {
            return nil
        }

        return (red, green, blue)
#elseif canImport(AppKit)
        guard let nativeColor = NSColor(self).usingColorSpace(.deviceRGB) else {
            return nil
        }

        return (nativeColor.redComponent, nativeColor.greenComponent, nativeColor.blueComponent)
#else
        return nil
#endif
    }

    private static func pasukiHexComponent(_ value: CGFloat) -> Int {
        Int(round(min(max(value, 0), 1) * 255))
    }
}
