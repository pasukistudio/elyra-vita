import Foundation
import SwiftData

// MARK: - FavoriteFood

/// Persistierter Snapshot eines favorisierten Lebensmittels.
///
/// Dadurch können lokale, eigene und externe Open-Food-Facts-Lebensmittel
/// gleichermaßen favorisiert und offline wieder ausgewählt werden.
@Model
final class FavoriteFood {

    var id: String = ""
    var name: String = ""
    var brand: String = ""
    var unit: String = "g"
    var pieceWeight: Double = 0
    var caloriesPer100: Double = 0
    var proteinPer100: Double = 0
    var carbohydratesPer100: Double = 0
    var fatPer100: Double = 0
    var sugarPer100: Double = 0
    var fiberPer100: Double = 0
    var saturatedFatPer100: Double = 0
    var saltPer100: Double = 0
    var source: String = "local"
    var barcode: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(food: NutritionFood) {
        let timestamp = Date()
        id = food.id
        name = food.name
        brand = food.brand
        unit = food.unit
        pieceWeight = food.pieceWeight ?? 0
        caloriesPer100 = food.caloriesPer100
        proteinPer100 = food.proteinPer100
        carbohydratesPer100 = food.carbohydratesPer100
        fatPer100 = food.fatPer100
        sugarPer100 = food.sugarPer100
        fiberPer100 = food.fiberPer100
        saturatedFatPer100 = food.saturatedFatPer100
        saltPer100 = food.saltPer100
        source = food.source
        barcode = food.barcode
        createdAt = timestamp
        updatedAt = timestamp
    }

    var nutritionFood: NutritionFood {
        NutritionFood(
            id: id,
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
            source: source,
            barcode: barcode
        )
    }
}
