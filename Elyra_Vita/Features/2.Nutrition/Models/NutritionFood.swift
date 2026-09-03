import Foundation

// MARK: - NutritionUnitOption

/// Eine auswählbare Eingabeeinheit für ein Lebensmittel.
///
/// `baseAmount` beschreibt, wie viele Gramm beziehungsweise Milliliter einer
/// Einheit entsprechen. Dadurch bleiben die Nährwerte weiterhin auf 100 g/ml
/// normiert, während die Oberfläche Stückangaben anbieten kann.
struct NutritionUnitOption: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let baseAmount: Double
}

// MARK: - NutritionFood

/// Katalogeintrag für die erste lokale deutsche Ernährungserfassung.
///
/// Alle Nährwerte beziehen sich auf 100 g beziehungsweise 100 ml. Externe
/// Datenquellen können später dieselbe Struktur mit ihren eigenen IDs liefern.
struct NutritionFood: Identifiable, Hashable {
    let id: String
    let name: String
    let brand: String
    let unit: String
    let pieceWeight: Double?
    let caloriesPer100: Double
    let proteinPer100: Double
    let carbohydratesPer100: Double
    let fatPer100: Double
    let sugarPer100: Double
    let fiberPer100: Double
    let saturatedFatPer100: Double
    let saltPer100: Double
    let source: String
    let barcode: String?

    init(
        id: String,
        name: String,
        brand: String,
        unit: String,
        pieceWeight: Double? = nil,
        caloriesPer100: Double,
        proteinPer100: Double,
        carbohydratesPer100: Double,
        fatPer100: Double,
        sugarPer100: Double = 0,
        fiberPer100: Double = 0,
        saturatedFatPer100: Double = 0,
        saltPer100: Double = 0,
        source: String = "local",
        barcode: String? = nil
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.unit = unit
        self.pieceWeight = pieceWeight
        self.caloriesPer100 = caloriesPer100
        self.proteinPer100 = proteinPer100
        self.carbohydratesPer100 = carbohydratesPer100
        self.fatPer100 = fatPer100
        self.sugarPer100 = sugarPer100
        self.fiberPer100 = fiberPer100
        self.saturatedFatPer100 = saturatedFatPer100
        self.saltPer100 = saltPer100
        self.source = source
        self.barcode = barcode
    }

    /// Rekonstruiert ein Lebensmittel aus dem gespeicherten Snapshot.
    static func from(entry: NutritionEntry) -> NutritionFood {
        let isPieceEntry = entry.unit == "piece" && entry.pieceWeight > 0
        let amountFactor: Double
        if isPieceEntry {
            amountFactor = max(entry.amount, 1) * entry.pieceWeight / 100
        } else if entry.unit == "g" || entry.unit == "ml" {
            amountFactor = max(entry.amount, 1) / 100
        } else {
            amountFactor = 1
        }

        return NutritionFood(
            id: entry.externalFoodID.isEmpty ? "entry-\(entry.foodName)-\(entry.date.timeIntervalSince1970)" : entry.externalFoodID,
            name: entry.foodName,
            brand: entry.brand,
            unit: isPieceEntry ? "g" : entry.unit,
            pieceWeight: isPieceEntry ? entry.pieceWeight : nil,
            caloriesPer100: entry.calories / amountFactor,
            proteinPer100: entry.proteinGrams / amountFactor,
            carbohydratesPer100: entry.carbohydratesGrams / amountFactor,
            fatPer100: entry.fatGrams / amountFactor,
            sugarPer100: entry.sugarGrams / amountFactor,
            fiberPer100: entry.fiberGrams / amountFactor,
            saturatedFatPer100: entry.saturatedFatGrams / amountFactor,
            saltPer100: entry.saltGrams / amountFactor,
            source: entry.source,
            barcode: entry.source == "openFoodFacts" ? entry.externalFoodID.replacingOccurrences(of: "off-", with: "") : nil
        )
    }

    // MARK: - Eingabeeinheiten

    /// Liefert die Basis- und – falls sinnvoll – eine Stückeinheit.
    var unitOptions: [NutritionUnitOption] {
        let baseUnit = unit == "piece" ? "g" : unit
        var options = [
            NutritionUnitOption(
                id: baseUnit,
                title: baseUnit == "ml" ? "Milliliter" : "Gramm",
                symbol: baseUnit,
                baseAmount: 1
            )
        ]

        if let pieceWeight, pieceWeight > 0 {
            options.append(
                NutritionUnitOption(
                    id: "piece",
                    title: "Stück",
                    symbol: "Stück",
                    baseAmount: pieceWeight
                )
            )
        }

        return options
    }

    /// Wandelt die eingegebene Menge in Gramm beziehungsweise Milliliter um.
    func baseAmount(for amount: Double, unit: String) -> Double {
        let option = unitOptions.first { $0.id == unit } ?? unitOptions[0]
        return amount * option.baseAmount
    }

    // MARK: - Lokaler deutscher Startkatalog

    static let localCatalog: [NutritionFood] = [
        NutritionFood(id: "apple", name: "Apfel", brand: "", unit: "g", pieceWeight: 180, caloriesPer100: 52, proteinPer100: 0.3, carbohydratesPer100: 11.4, fatPer100: 0.2, sugarPer100: 10.4, fiberPer100: 2.4, saturatedFatPer100: 0, saltPer100: 0),
        NutritionFood(id: "banana", name: "Banane", brand: "", unit: "g", pieceWeight: 120, caloriesPer100: 89, proteinPer100: 1.1, carbohydratesPer100: 22.8, fatPer100: 0.3, sugarPer100: 12.2, fiberPer100: 2.6, saturatedFatPer100: 0.1, saltPer100: 0),
        NutritionFood(id: "bread-roll", name: "Weizenbrötchen", brand: "", unit: "g", pieceWeight: 60, caloriesPer100: 270, proteinPer100: 8.5, carbohydratesPer100: 52, fatPer100: 3.2, sugarPer100: 3.5, fiberPer100: 3.2, saturatedFatPer100: 0.5, saltPer100: 1.2),
        NutritionFood(id: "oatmeal", name: "Haferflocken", brand: "", unit: "g", caloriesPer100: 372, proteinPer100: 13.5, carbohydratesPer100: 58.7, fatPer100: 7, sugarPer100: 0.7, fiberPer100: 10, saturatedFatPer100: 1.3, saltPer100: 0.01),
        NutritionFood(id: "rice-cooked", name: "Reis, gekocht", brand: "", unit: "g", caloriesPer100: 130, proteinPer100: 2.7, carbohydratesPer100: 28.2, fatPer100: 0.3, sugarPer100: 0.1, fiberPer100: 0.4, saturatedFatPer100: 0.1, saltPer100: 0),
        NutritionFood(id: "pasta-cooked", name: "Nudeln, gekocht", brand: "", unit: "g", caloriesPer100: 158, proteinPer100: 5.8, carbohydratesPer100: 30.9, fatPer100: 0.9, sugarPer100: 0.6, fiberPer100: 1.8, saturatedFatPer100: 0.2, saltPer100: 0.01),
        NutritionFood(id: "egg", name: "Ei", brand: "", unit: "g", pieceWeight: 60, caloriesPer100: 143, proteinPer100: 12.6, carbohydratesPer100: 0.7, fatPer100: 9.5, sugarPer100: 0.4, fiberPer100: 0, saturatedFatPer100: 3.1, saltPer100: 0.36),
        NutritionFood(id: "milk", name: "Milch 1,5 %", brand: "", unit: "ml", caloriesPer100: 47, proteinPer100: 3.4, carbohydratesPer100: 4.8, fatPer100: 1.5, sugarPer100: 4.8, fiberPer100: 0, saturatedFatPer100: 1, saltPer100: 0.1),
        NutritionFood(id: "yogurt", name: "Naturjoghurt", brand: "", unit: "g", caloriesPer100: 61, proteinPer100: 3.5, carbohydratesPer100: 4.7, fatPer100: 3.3, sugarPer100: 4.7, fiberPer100: 0, saturatedFatPer100: 2.1, saltPer100: 0.1),
        NutritionFood(id: "chicken-breast", name: "Hähnchenbrust", brand: "", unit: "g", caloriesPer100: 110, proteinPer100: 23.1, carbohydratesPer100: 0, fatPer100: 1.2, sugarPer100: 0, fiberPer100: 0, saturatedFatPer100: 0.3, saltPer100: 0.15)
    ]
}
