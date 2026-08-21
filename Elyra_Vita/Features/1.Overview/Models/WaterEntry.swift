import Foundation
import SwiftData

/// Ein einzelner Wassereintrag für einen bestimmten Zeitpunkt.
@Model
final class WaterEntry {

    // MARK: - Trinkereignis

    // CloudKit benötigt für alle nicht-optionalen Attribute einen
    // direkt am Modell definierten Standardwert.
    var date: Date = Date()
    var amount: Int = 0

    // MARK: - Synchronisationsmetadaten

    /// Zeitpunkt der Erstellung des Trinkereignisses.
    var createdAt: Date = Date()

    /// Zeitpunkt der letzten fachlichen Änderung am Eintrag.
    var updatedAt: Date = Date()

    init(date: Date = .now, amount: Int) {
        let timestamp = Date()
        self.date = date
        self.amount = amount
        self.createdAt = timestamp
        self.updatedAt = timestamp
    }

    // MARK: - Änderungen

    /// Ändert einen Eintrag und setzt den Konfliktzeitstempel zentral.
    func update(date: Date? = nil, amount: Int? = nil) {
        if let date {
            self.date = date
        }

        if let amount, amount > 0 {
            self.amount = amount
        }

        updatedAt = .now
    }
}
