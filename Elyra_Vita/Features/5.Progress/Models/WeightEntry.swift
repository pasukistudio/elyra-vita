import Foundation
import SwiftData

// MARK: - WeightEntry

/// Eine manuelle Gewichtsmessung zu einem bestimmten Zeitpunkt.
@Model
final class WeightEntry {

    // MARK: - Messung

    // CloudKit-kompatible Standardwerte für den SwiftData-Store.
    var date: Date = Date()
    var weightKilograms: Double = 0

    // MARK: - Synchronisationsmetadaten

    /// Zeitpunkt, an dem die Messung angelegt wurde.
    var createdAt: Date = Date()

    /// Zeitpunkt der letzten fachlichen Änderung.
    var updatedAt: Date = Date()

    // MARK: - Initialisierung

    init(date: Date = .now, weightKilograms: Double) {
        let timestamp = Date()
        self.date = date
        self.weightKilograms = max(0.1, weightKilograms)
        self.createdAt = timestamp
        self.updatedAt = timestamp
    }

    // MARK: - Änderungen

    /// Ändert Messwert oder Zeitpunkt und aktualisiert den Konfliktzeitstempel.
    func update(date: Date? = nil, weightKilograms: Double? = nil) {
        if let date {
            self.date = date
        }

        if let weightKilograms, weightKilograms > 0 {
            self.weightKilograms = weightKilograms
        }

        updatedAt = .now
    }
}
