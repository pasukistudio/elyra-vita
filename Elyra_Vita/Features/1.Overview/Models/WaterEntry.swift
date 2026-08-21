import Foundation
import SwiftData

/// Ein einzelner Wassereintrag für einen bestimmten Zeitpunkt.
@Model
final class WaterEntry {
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
}
