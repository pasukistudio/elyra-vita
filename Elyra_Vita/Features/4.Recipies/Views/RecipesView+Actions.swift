import SwiftData
import SwiftUI

extension RecipesView {
    func toggleFavorite(_ recipe: Recipe) {
        recipe.isFavorite.toggle()
        recipe.updatedAt = .now
        _ = PersistenceErrorReporter.save(modelContext, operation: "Rezeptfavorit ändern")
    }

    func delete(_ recipe: Recipe) {
        ingredients.filter { $0.recipeID == recipe.id }.forEach { modelContext.delete($0) }
        steps.filter { $0.recipeID == recipe.id }.forEach { modelContext.delete($0) }
        memberships.filter { $0.recipeID == recipe.id }.forEach { modelContext.delete($0) }
        modelContext.delete(recipe)
        if PersistenceErrorReporter.save(modelContext, operation: "Rezept löschen") {
            deletingRecipe = nil
        }
    }

    var deletingPresented: Binding<Bool> {
        Binding(get: { deletingRecipe != nil }, set: {
            if !$0 {
                deletingRecipe = nil
            }
        })
    }
}
