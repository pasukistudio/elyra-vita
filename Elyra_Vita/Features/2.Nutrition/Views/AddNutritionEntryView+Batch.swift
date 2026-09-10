import SwiftUI

extension AddNutritionEntryView {
    func resetForNextFood() {
        selectedFood = nil
        searchText = ""
        remoteFoods = []
        amountText = "100"
        pieceWeightText = ""
        selectedUnit = "g"
        caloriesText = ""
        proteinText = ""
        carbohydratesText = ""
        fatText = ""
        sugarText = ""
        fiberText = ""
        saturatedFatText = ""
        saltText = ""
    }
}
