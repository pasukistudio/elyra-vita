import Foundation
import SwiftData
import PasukiUI

// MARK: - UserSettings

/// Persistierte, geräteübergreifend synchronisierte Benutzereinstellungen.
@Model
final class UserSettings {

    // MARK: - Profil-Daten

    var name: String = ""

    // MARK: - Erscheinungsbild

    var appearanceRawValue: String =
        AppAppearance.system.rawValue

    var accentColorRawValue: String =
        AppAccentColor.blue.rawValue

    /// Frei gewählte Akzentfarbe als Hexwert.
    var customAccentHex: String = "#007AFF"

    // MARK: - Vita-spezifische Tagesziele

    /// Elyra-Vita-spezifisches Wasserziel in Millilitern.
    var waterGoalML: Int = 2_500

    // MARK: - Benachrichtigungen

    // Weitere Benachrichtigungseinstellungen werden später ergänzt.

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
        customAccentHex: String = "#007AFF",
        waterGoalML: Int = 2_500
    ) {
        self.name = name
        self.appearanceRawValue = appearanceRawValue
        self.accentColorRawValue = accentColorRawValue
        self.customAccentHex = customAccentHex
        self.waterGoalML = min(max(waterGoalML, 500), 6_000)
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Änderungen

    /// Markiert die Einstellungen als fachlich geändert.
    func markUpdated() {
        updatedAt = .now
    }
}
