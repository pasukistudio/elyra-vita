import SwiftUI
import PasukiUI

// MARK: - AppAccentColor

/// App-Auswahl für eine Akzentfarbe.
///
/// Die festen Farben kommen vollständig aus PasukiUI. Elyra Vita ergänzt nur
/// die freie Auswahl, weil diese Auswahl später über Pro geschützt werden kann.
struct AppAccentColor: RawRepresentable, CaseIterable, Identifiable, Hashable {

    // MARK: - Werte

    let rawValue: String

    // MARK: - Gemeinsame Presets

    static let red = Self(rawValue: PasukiColorPreset.red.rawValue)
    static let orange = Self(rawValue: PasukiColorPreset.orange.rawValue)
    static let green = Self(rawValue: PasukiColorPreset.green.rawValue)
    static let teal = Self(rawValue: PasukiColorPreset.teal.rawValue)
    static let cyan = Self(rawValue: PasukiColorPreset.cyan.rawValue)
    static let blue = Self(rawValue: PasukiColorPreset.blue.rawValue)
    static let indigo = Self(rawValue: PasukiColorPreset.indigo.rawValue)
    static let purple = Self(rawValue: PasukiColorPreset.purple.rawValue)
    static let pink = Self(rawValue: PasukiColorPreset.pink.rawValue)
    static let gray = Self(rawValue: PasukiColorPreset.gray.rawValue)

    // MARK: - App-spezifische Auswahl

    static let custom = Self(rawValue: "custom")

    // MARK: - CaseIterable

    static let allCases: [Self] = [
        .red, .orange, .green, .teal, .cyan,
        .blue, .indigo, .purple, .pink, .gray, .custom
    ]

    // MARK: - Identifiable

    var id: String { rawValue }

    // MARK: - Darstellung

    var title: LocalizedStringResource {
        if self == .custom {
            return "Eigene Farbe"
        }

        return preset?.title ?? ""
    }

    var preset: PasukiColorPreset? {
        PasukiColorPreset(rawValue: rawValue)
    }

    var color: Color? {
        preset?.color
    }

    // MARK: - Pro-Zugriff

    var requiredProFeature: PasukiProFeature? {
        guard self == .custom else { return nil }
        return .customAccentColor
    }

    var isProOnly: Bool {
        requiredProFeature != nil
    }

    // MARK: - Gemeinsames Auswahlmodell

    func selection(customHex: String = "") -> PasukiAccentColorSelection {
        if self == .custom {
            return .custom(hex: customHex)
        }

        return .preset(preset ?? .blue)
    }
}
