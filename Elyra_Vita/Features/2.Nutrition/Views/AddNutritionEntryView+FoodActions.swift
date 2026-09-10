import Foundation
import SwiftData

extension AddNutritionEntryView {
    func recentlyUsedEntry(for food: NutritionFood) -> NutritionEntry? {
        nutritionEntries.first {
            if !$0.externalFoodID.isEmpty {
                return $0.externalFoodID == food.id
            }
            return $0.foodName.localizedCaseInsensitiveCompare(food.name) == .orderedSame
        }
    }

    func isFavorite(_ food: NutritionFood) -> Bool {
        favoriteFoods.contains { $0.id == food.id }
    }

    func toggleFavorite(_ food: NutritionFood) {
        if let favorite = favoriteFoods.first(where: { $0.id == food.id }) {
            modelContext.delete(favorite)
        } else {
            modelContext.insert(FavoriteFood(food: food))
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}
