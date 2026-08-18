import Foundation
import SwiftData

@Model
final class UserSettings {

    // MARK: - Profil-Daten

    var name: String = ""

    // MARK: - Erscheinungsbild

    var appearanceRawValue: String =
        AppAppearance.system.rawValue

    var accentColorRawValue: String =
        AppAccentColor.blue.rawValue

    var customAccentHex: String = "#007AFF"

    // MARK: - Benachrichtigungen

    // Hier kommen spaeter Benachrichtigungseinstellungen hinzu.

    // MARK: - Zeitstempel

    /// Zeitpunkt der Profilerstellung.
    var createdAt: Date = Date()

    /// Zeitpunkt der letzten gespeicherten Aenderung.
    var updatedAt: Date = Date()

    // MARK: - Initialisierung

    init(
        name: String = "",
        appearanceRawValue: String =
            AppAppearance.system.rawValue,
        accentColorRawValue: String =
            AppAccentColor.blue.rawValue,
        customAccentHex: String = "#007AFF"
    ) {
        self.name = name
        self.appearanceRawValue = appearanceRawValue
        self.accentColorRawValue = accentColorRawValue
        self.customAccentHex = customAccentHex
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
