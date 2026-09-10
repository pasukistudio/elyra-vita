import Foundation

struct ScannedCookingProduct: Identifiable {
    let id = UUID()
    let food: NutritionFood
    var matchedIngredient: String
    var amountText = "100"
    var unit: String {
        food.unit
    }
}
