import Foundation
import SwiftData
import SwiftUI

extension AddNutritionEntryView {
    func save(finishBatch: Bool) {
        guard let selectedFood,
              let amount = parsedAmount,
              amount > 0,
              let values = nutritionValues,
              values.count == 8 else { return }

        if let entryToEdit {
            entryToEdit.foodName = selectedFood.name
            entryToEdit.brand = selectedFood.brand
            entryToEdit.unit = selectedUnit
            entryToEdit.pieceWeight = pieceWeight ?? 0
            entryToEdit.externalFoodID = selectedFood.id
            entryToEdit.source = selectedFood.source
            entryToEdit.update(mealType: selectedMealType, amount: amount, date: entryToEdit.date)
            entryToEdit.calories = values[0]
            entryToEdit.proteinGrams = values[1]
            entryToEdit.carbohydratesGrams = values[2]
            entryToEdit.fatGrams = values[3]
            entryToEdit.sugarGrams = values[4]
            entryToEdit.fiberGrams = values[5]
            entryToEdit.saturatedFatGrams = values[6]
            entryToEdit.saltGrams = values[7]
            entryToEdit.updatedAt = .now
        } else {
            modelContext.insert(NutritionEntry(
                foodName: selectedFood.name,
                brand: selectedFood.brand,
                mealType: selectedMealType,
                amount: amount,
                unit: selectedUnit,
                pieceWeight: pieceWeight ?? 0,
                calories: values[0],
                proteinGrams: values[1],
                carbohydratesGrams: values[2],
                fatGrams: values[3],
                sugarGrams: values[4],
                fiberGrams: values[5],
                saturatedFatGrams: values[6],
                saltGrams: values[7],
                date: selectedDate,
                source: selectedFood.source,
                externalFoodID: selectedFood.id
            ))
        }

        guard PersistenceErrorReporter.save(modelContext, operation: "Ernährungseintrag speichern") else { return }

        if entryToEdit != nil || finishBatch {
            dismiss()
        } else {
            savedFoodCount += 1
            resetForNextFood()
        }
    }
}
