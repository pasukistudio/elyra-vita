import Foundation
import SwiftData
import SwiftUI

extension RecipeEditorView {
    func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if recipe == nil, titleAlreadyExists(trimmedTitle) {
            errorMessage = "Ein Rezept mit diesem Namen existiert bereits."
            return
        }

        let drafts = normalizedDrafts()
        guard let savedRecipe = prepareRecipe(title: trimmedTitle) else { return }
        insertRelatedData(for: savedRecipe, ingredients: drafts.ingredients, steps: drafts.steps)
        persistChanges()
    }

    private func titleAlreadyExists(_ title: String) -> Bool {
        existingRecipes.contains {
            $0.title.compare(title, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    private func normalizedDrafts() -> (ingredients: [IngredientDraft], steps: [StepDraft]) {
        let validIngredients = ingredients.enumerated().compactMap { index, draft -> IngredientDraft? in
            guard !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return draft.withPosition(index)
        }
        let validSteps = steps.map {
            StepDraft(
                instruction: $0.instruction.trimmingCharacters(in: .whitespacesAndNewlines),
                durationSeconds: $0.durationSeconds
            )
        }.filter { !$0.instruction.isEmpty }
        return (validIngredients, validSteps)
    }

    private func prepareRecipe(title: String) -> Recipe? {
        if let recipe {
            update(recipe: recipe, title: title)
            do {
                try deleteRelatedData(for: recipe.id)
            } catch {
                errorMessage = error.localizedDescription
                return nil
            }
            return recipe
        }

        let newRecipe = Recipe(
            title: title,
            servings: servings,
            prepMinutes: prepMinutes,
            category: category,
            imageURL: imageURL,
            sourceURL: sourceURL
        )
        update(recipe: newRecipe, title: title)
        modelContext.insert(newRecipe)
        return newRecipe
    }

    private func insertRelatedData(
        for recipe: Recipe,
        ingredients: [IngredientDraft],
        steps: [StepDraft]
    ) {
        for (index, ingredient) in ingredients.enumerated() {
            modelContext.insert(RecipeIngredient(
                recipeID: recipe.id,
                name: ingredient.name,
                amount: ingredient.amount,
                unit: ingredient.unit,
                position: index
            ))
        }
        for (index, step) in steps.enumerated() {
            modelContext.insert(RecipeStep(
                recipeID: recipe.id,
                instruction: step.instruction,
                position: index,
                durationSeconds: step.durationSeconds
            ))
        }
        for selectedBookID in selectedBookIDs {
            modelContext.insert(RecipeBookMembership(recipeID: recipe.id, bookID: selectedBookID))
        }
    }

    private func persistChanges() {
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func update(recipe: Recipe, title: String) {
        recipe.title = title
        recipe.note = note
        recipe.servings = servings
        recipe.prepMinutes = prepMinutes
        recipe.category = category
        recipe.imageURL = imageURL
        recipe.sourceURL = sourceURL
        recipe.caloriesPerServing = parsed(caloriesPerServingText)
        recipe.proteinPerServing = parsed(proteinPerServingText)
        recipe.carbohydratesPerServing = parsed(carbohydratesPerServingText)
        recipe.fatPerServing = parsed(fatPerServingText)
        recipe.updatedAt = .now
    }

    private func deleteRelatedData(for recipeID: UUID) throws {
        let ingredientDescriptor = FetchDescriptor<RecipeIngredient>(predicate: #Predicate { $0.recipeID == recipeID })
        try modelContext.fetch(ingredientDescriptor).forEach(modelContext.delete)
        let stepDescriptor = FetchDescriptor<RecipeStep>(predicate: #Predicate { $0.recipeID == recipeID })
        try modelContext.fetch(stepDescriptor).forEach(modelContext.delete)
        let membershipDescriptor = FetchDescriptor<RecipeBookMembership>(
            predicate: #Predicate { $0.recipeID == recipeID }
        )
        try modelContext.fetch(membershipDescriptor).forEach(modelContext.delete)
    }
}
