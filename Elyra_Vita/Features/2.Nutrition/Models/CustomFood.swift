import Foundation
import SwiftData

// MARK: - CustomFood

/// Ein vom Nutzer gepflegtes Lebensmittel im persönlichen Katalog.
///
/// Die Nährwerte gelten immer für 100 g beziehungsweise 100 ml. Alle
/// Attribute besitzen CloudKit-kompatible Standardwerte; `updatedAt` macht
/// spätere Konfliktprüfungen nachvollziehbar.
@Model
final class CustomFood {

    // MARK: - Identität und Beschreibung

    var id: String = UUID().uuidString
    var name: String = ""
    var brand: String = ""
    var unit: String = "g"
    var pieceWeight: Double = 0
    var source: String = "custom"

    // MARK: - Nährwerte pro 100 g/ml

    var caloriesPer100: Double = 0
    var proteinPer100: Double = 0
    var carbohydratesPer100: Double = 0
    var fatPer100: Double = 0
    var sugarPer100: Double = 0
    var fiberPer100: Double = 0
    var saturatedFatPer100: Double = 0
    var saltPer100: Double = 0

    // MARK: - Zeitstempel

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Initialisierung

    init(
        name: String,
        brand: String = "",
        unit: String = "g",
        pieceWeight: Double? = nil,
        caloriesPer100: Double = 0,
        proteinPer100: Double = 0,
        carbohydratesPer100: Double = 0,
        fatPer100: Double = 0,
        sugarPer100: Double = 0,
        fiberPer100: Double = 0,
        saturatedFatPer100: Double = 0,
        saltPer100: Double = 0
    ) {
        let timestamp = Date()
        self.id = UUID().uuidString
        self.name = name
        self.brand = brand
        self.unit = unit
        self.pieceWeight = max(0, pieceWeight ?? 0)
        self.caloriesPer100 = max(0, caloriesPer100)
        self.proteinPer100 = max(0, proteinPer100)
        self.carbohydratesPer100 = max(0, carbohydratesPer100)
        self.fatPer100 = max(0, fatPer100)
        self.sugarPer100 = max(0, sugarPer100)
        self.fiberPer100 = max(0, fiberPer100)
        self.saturatedFatPer100 = max(0, saturatedFatPer100)
        self.saltPer100 = max(0, saltPer100)
        self.createdAt = timestamp
        self.updatedAt = timestamp
    }

    // MARK: - Umwandlung

    /// Liefert die gemeinsame, nicht persistierte Darstellung für den
    /// bestehenden Erfassungsdialog.
    var nutritionFood: NutritionFood {
        NutritionFood(
            id: "custom-\(id)",
            name: name,
            brand: brand,
            unit: unit,
            pieceWeight: pieceWeight > 0 ? pieceWeight : nil,
            caloriesPer100: caloriesPer100,
            proteinPer100: proteinPer100,
            carbohydratesPer100: carbohydratesPer100,
            fatPer100: fatPer100,
            sugarPer100: sugarPer100,
            fiberPer100: fiberPer100,
            saturatedFatPer100: saturatedFatPer100,
            saltPer100: saltPer100,
            source: source
        )
    }
}
