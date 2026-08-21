import SwiftUI

// MARK: - PasukiAppearance

/// Gemeinsame Darstellungseinstellungen für Pasuki-Apps.
public enum PasukiAppearance: String, CaseIterable, Identifiable, Sendable {

    // MARK: - Modi

    case system
    case light
    case dark

    // MARK: - Identifiable

    public var id: Self { self }

    // MARK: - Anzeige

    public var title: LocalizedStringResource {
        switch self {
        case .system: "System"
        case .light: "Hell"
        case .dark: "Dunkel"
        }
    }

    public var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    // MARK: - SwiftUI-Darstellung

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
