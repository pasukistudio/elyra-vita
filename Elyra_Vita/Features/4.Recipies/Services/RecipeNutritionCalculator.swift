import Foundation

struct RecipeIngredientValue {
    let amount: String
    let unit: String
    let name: String
}

struct RecipeNutritionTotals {
    var calories = 0.0
    var protein = 0.0
    var carbohydrates = 0.0
    var fat = 0.0
    var recognizedIngredients = 0
    var unrecognizedIngredients = 0
}

struct RecipeNutritionCalculator {
    func calculate(
        ingredients: [RecipeIngredientValue],
        foods: [NutritionFood],
        servings: Int
    ) -> RecipeNutritionTotals {
        var totals = RecipeNutritionTotals()
        for ingredient in ingredients {
            guard let food = bestMatch(for: ingredient.name, in: foods),
                  let amount = parseAmount(ingredient.amount), amount > 0,
                  let baseAmount = baseAmount(amount: amount, unit: ingredient.unit, food: food)
            else {
                if !ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    totals.unrecognizedIngredients += 1
                }
                continue
            }

            let factor = baseAmount / 100
            totals.calories += food.caloriesPer100 * factor
            totals.protein += food.proteinPer100 * factor
            totals.carbohydrates += food.carbohydratesPer100 * factor
            totals.fat += food.fatPer100 * factor
            totals.recognizedIngredients += 1
        }

        let divisor = Double(max(servings, 1))
        totals.calories /= divisor
        totals.protein /= divisor
        totals.carbohydrates /= divisor
        totals.fat /= divisor
        return totals
    }

    private func bestMatch(for name: String, in foods: [NutritionFood]) -> NutritionFood? {
        let normalizedName = normalize(name)
        guard !normalizedName.isEmpty else { return nil }
        return foods
            .filter { candidate in
                let normalizedCandidate = normalize(candidate.name)
                return normalizedName == normalizedCandidate ||
                    normalizedName.contains(normalizedCandidate) ||
                    normalizedCandidate.contains(normalizedName)
            }
            .sorted { normalize($0.name).count > normalize($1.name).count }
            .first
    }

    private func baseAmount(amount: Double, unit: String, food: NutritionFood) -> Double? {
        switch unit.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "g", "gramm", "gram": return amount
        case "kg": return amount * 1000
        case "ml": return amount
        case "l": return amount * 1000
        case "stück", "stueck", "piece":
            guard let pieceWeight = food.pieceWeight, pieceWeight > 0 else { return nil }
            return amount * pieceWeight
        default: return nil
        }
    }

    private func parseAmount(_ text: String) -> Double? {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        if let value = Double(cleaned) {
            return value
        }
        let parts = cleaned.split(separator: "/")
        guard parts.count == 2,
              let numerator = Double(parts[0].trimmingCharacters(in: .whitespaces)),
              let denominator = Double(parts[1].trimmingCharacters(in: .whitespaces)),
              denominator != 0 else { return nil }
        return numerator / denominator
    }

    private func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "[^a-z0-9äöüß ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
