import Foundation

// MARK: - PasukiProFeature

/// Gemeinsame Pro-Funktionen, die von mehreren Pasuki-Apps genutzt werden.
public enum PasukiProFeature: String, CaseIterable, Sendable {

    // MARK: - Funktionen

    /// Freie Auswahl einer eigenen Akzentfarbe.
    case customAccentColor
}

// MARK: - PasukiProAccess

/// Liefert den Entitlement-Status einer gemeinsamen Pro-Funktion.
@MainActor
public protocol PasukiProAccess {
    func hasAccess(to feature: PasukiProFeature) -> Bool
}

// MARK: - PasukiAccentColorSelection

/// Gemeinsames Auswahlmodell für Preset- und eigene Akzentfarben.
public enum PasukiAccentColorSelection: Equatable, Sendable {

    // MARK: - Auswahltypen

    case preset(PasukiColorPreset)
    case custom(hex: String)

    // MARK: - Zugriffsregel

    /// Die freie Farbauswahl ist die einzige Pro-geschützte Auswahl.
    public var requiredProFeature: PasukiProFeature? {
        switch self {
        case .preset:
            nil
        case .custom:
            .customAccentColor
        }
    }

    /// Prüft die Auswahl gegen den übergebenen Entitlement-Service.
    @MainActor
    public func isAvailable(for proAccess: any PasukiProAccess) -> Bool {
        guard let requiredProFeature else { return true }
        return proAccess.hasAccess(to: requiredProFeature)
    }
}
