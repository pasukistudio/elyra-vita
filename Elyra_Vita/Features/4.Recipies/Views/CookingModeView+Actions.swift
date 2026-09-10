import SwiftData
import SwiftUI

extension CookingModeView {
    var timerText: String {
        String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60)
    }

    var currentStepDuration: Int {
        guard !steps.isEmpty, steps.indices.contains(currentStep) else { return 0 }
        return max(0, steps.sorted { $0.position < $1.position }[currentStep].durationSeconds)
    }

    func startTimer(seconds: Int) {
        remainingSeconds = max(1, seconds)
        timerRunning = true
    }

    func stopTimer() {
        timerRunning = false
        remainingSeconds = 0
    }

    func loadProduct(barcode: String) async {
        do {
            guard let food = try await OpenFoodFactsService().product(for: barcode) else {
                scanMessage = "Dieses Produkt wurde nicht gefunden."
                return
            }
            let match = bestIngredientMatch(for: food)
            if let match {
                checkedIngredientIDs.insert(match.id)
            }
            scannedProducts.append(ScannedCookingProduct(food: food, matchedIngredient: match?.name ?? ""))
            scanMessage = match == nil
                ? "\(food.name) wurde erfasst. Bitte ordne das Produkt beim Rezept zu."
                : "\(food.name) wurde \"\(match?.name ?? "")\" zugeordnet."
        } catch {
            scanMessage = "Das Produkt konnte nicht geladen werden. Bitte versuche es erneut."
        }
    }

    func saveScannedProducts() {
        for product in scannedProducts {
            let amount = Double(product.amountText.replacingOccurrences(of: ",", with: ".")) ?? 100
            let factor = max(amount, 0) / 100
            modelContext.insert(NutritionEntry(
                foodName: product.food.name,
                brand: product.food.brand,
                mealType: .snack,
                amount: max(amount, 0),
                unit: product.unit,
                calories: product.food.caloriesPer100 * factor,
                proteinGrams: product.food.proteinPer100 * factor,
                carbohydratesGrams: product.food.carbohydratesPer100 * factor,
                fatGrams: product.food.fatPer100 * factor,
                sugarGrams: product.food.sugarPer100 * factor,
                fiberGrams: product.food.fiberPer100 * factor,
                saturatedFatGrams: product.food.saturatedFatPer100 * factor,
                saltGrams: product.food.saltPer100 * factor,
                source: product.food.source,
                externalFoodID: product.food.id
            ))
        }
        if PersistenceErrorReporter.save(modelContext, operation: "Gescannte Kochzutaten speichern") {
            scanMessage = "\(scannedProducts.count) Produkt(e) wurden als gegessen eingetragen."
        }
    }

    func finishCooking(portions: Double) {
        if scannedProducts.isEmpty {
            let multiplier = max(portions, 0)
            modelContext.insert(NutritionEntry(
                foodName: recipe.title,
                mealType: .snack,
                amount: multiplier,
                unit: "portion",
                calories: recipe.caloriesPerServing * multiplier,
                proteinGrams: recipe.proteinPerServing * multiplier,
                carbohydratesGrams: recipe.carbohydratesPerServing * multiplier,
                fatGrams: recipe.fatPerServing * multiplier,
                source: "recipe",
                externalFoodID: recipe.id.uuidString
            ))
            _ = PersistenceErrorReporter.save(modelContext, operation: "Rezept kochen abschließen")
        } else {
            saveScannedProducts()
        }
        dismiss()
    }

    private func bestIngredientMatch(for food: NutritionFood) -> RecipeIngredient? {
        let productTokens = meaningfulTokens(food.name)
        return ingredients
            .map { ingredient in
                (ingredient, meaningfulTokens(ingredient.name).intersection(productTokens).count)
            }
            .filter { $0.1 > 0 }
            .max { $0.1 < $1.1 }?.0
    }

    private func meaningfulTokens(_ value: String) -> Set<String> {
        let ignored: Set = ["und", "oder", "mit", "für", "im", "in", "der", "die", "das"]
        return Set(value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
            .filter { $0.count > 2 && !ignored.contains($0) })
    }

    var scanMessagePresented: Binding<Bool> {
        Binding(get: { scanMessage != nil }, set: {
            if !$0 {
                scanMessage = nil
            }
        })
    }
}
