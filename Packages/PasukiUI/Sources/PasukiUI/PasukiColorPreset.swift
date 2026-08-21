import Foundation
import SwiftUI

// MARK: - PasukiColorPreset

/// Gemeinsame Akzentfarbpalette für alle Pasuki-Apps.
///
/// Produktregeln wie eigene Farben oder Pro-Einschränkungen gehören in die
/// jeweilige App. Dieses Modell enthält nur gemeinsame Presets und Werte.
public enum PasukiColorPreset: String, CaseIterable, Identifiable, Sendable {

    // MARK: - Presets

    case red
    case orange
    case green
    case teal
    case cyan
    case blue
    case indigo
    case purple
    case pink
    case gray

    // MARK: - Identifiable

    public var id: Self { self }

    // MARK: - Anzeigename

    public var title: LocalizedStringResource {
        switch self {
        case .red: "Rot"
        case .orange: "Orange"
        case .green: "Grün"
        case .teal: "Türkis"
        case .cyan: "Cyan"
        case .blue: "Blau"
        case .indigo: "Indigo"
        case .purple: "Lila"
        case .pink: "Rosa"
        case .gray: "Grau"
        }
    }

    // MARK: - Farbwerte

    public var hex: String {
        switch self {
        case .red: "#FF3B30"
        case .orange: "#FF9500"
        case .green: "#34C759"
        case .teal: "#00C7BE"
        case .cyan: "#32ADE6"
        case .blue: "#007AFF"
        case .indigo: "#5856D6"
        case .purple: "#AF52DE"
        case .pink: "#FF2D55"
        case .gray: "#8E8E93"
        }
    }

    /// SwiftUI-Farbe des Presets.
    public var color: Color { Color(hexString: hex) }
}
