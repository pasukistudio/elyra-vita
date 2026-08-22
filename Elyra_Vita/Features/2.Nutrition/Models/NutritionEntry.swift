import Foundation
import SwiftData

// MARK: - NutritionMealType

/// Mahlzeitentypen, die in der Tagesansicht angeboten werden.
enum NutritionMealType: String, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breakfast: "Frühstück"
        case .lunch: "Mittagessen"
        case .dinner: "Abendessen"
        case .snack: "Snack"
        }
    }

    var icon: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .lunch: "sun.max.fill"
        case .dinner: "moon.stars.fill"
        case .snack: "leaf.fill"
        }
    }

    /// Reihenfolge des Tageslogbuchs: Abendessen, Mittagessen, Frühstück, Snacks.
    var displayOrder: Int {
        switch self {
        case .dinner: 0
        case .lunch: 1
        case .breakfast: 2
        case .snack: 3
        }
    }
}

// MARK: - NutritionEntry

/// Ein gespeicherter Verzehr eines Lebensmittels.
///
/// Die Nährwerte werden beim Speichern als Snapshot übernommen. Dadurch
/// verändern spätere Katalogänderungen bereits geloggte Tage nicht rückwirkend.
@Model
final class NutritionEntry {

    // MARK: - Lebensmittel und Menge

    // CloudKit-kompatible Standardwerte für alle nicht optionalen Attribute.
    var foodName: String = ""
    var brand: String = ""
    var mealTypeRawValue: String = NutritionMealType.snack.rawValue
    var amount: Double = 0
    var unit: String = "g"
    /// Gespeicherte Umrechnung für eigene Stückdefinitionen, z. B. 1 Stück = 50 g.
    var pieceWeight: Double = 0

    // MARK: - Nährwert-Snapshot

    var calories: Double = 0
    var proteinGrams: Double = 0
    var carbohydratesGrams: Double = 0
    var fatGrams: Double = 0
    var sugarGrams: Double = 0
    var fiberGrams: Double = 0
    var saturatedFatGrams: Double = 0
    var saltGrams: Double = 0
    var source: String = "local"
    var externalFoodID: String = ""

    // MARK: - Zeitstempel

    var date: Date = Date()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Initialisierung

    init(
        foodName: String,
        brand: String = "",
        mealType: NutritionMealType,
        amount: Double,
        unit: String,
        pieceWeight: Double = 0,
        calories: Double,
        proteinGrams: Double = 0,
        carbohydratesGrams: Double = 0,
        fatGrams: Double = 0,
        sugarGrams: Double = 0,
        fiberGrams: Double = 0,
        saturatedFatGrams: Double = 0,
        saltGrams: Double = 0,
        date: Date = .now,
        source: String = "local",
        externalFoodID: String = ""
    ) {
        let timestamp = Date()
        self.foodName = foodName
        self.brand = brand
        self.mealTypeRawValue = mealType.rawValue
        self.amount = max(0, amount)
        self.unit = unit
        self.pieceWeight = max(0, pieceWeight)
        self.calories = max(0, calories)
        self.proteinGrams = max(0, proteinGrams)
        self.carbohydratesGrams = max(0, carbohydratesGrams)
        self.fatGrams = max(0, fatGrams)
        self.sugarGrams = max(0, sugarGrams)
        self.fiberGrams = max(0, fiberGrams)
        self.saturatedFatGrams = max(0, saturatedFatGrams)
        self.saltGrams = max(0, saltGrams)
        self.date = date
        self.source = source
        self.externalFoodID = externalFoodID
        self.createdAt = timestamp
        self.updatedAt = timestamp
    }

    // MARK: - Darstellung und Änderungen

    var mealType: NutritionMealType {
        NutritionMealType(rawValue: mealTypeRawValue) ?? .snack
    }

    /// Aktualisiert einen Eintrag und setzt den Konfliktzeitstempel.
    func update(
        mealType: NutritionMealType,
        amount: Double,
        date: Date
    ) {
        self.mealTypeRawValue = mealType.rawValue
        self.amount = max(0, amount)
        self.date = date
        updatedAt = .now
    }
}
