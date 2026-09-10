import Foundation
import SwiftData

@Model
final class Recipe {
    var id: UUID = UUID()
    var title: String = ""
    var note: String = ""
    var servings: Int = 2
    var prepMinutes: Int = 0
    var category: String = ""
    var imageURL: String = ""
    var isFavorite: Bool = false
    var sourceURL: String = ""
    var caloriesPerServing: Double = 0
    var proteinPerServing: Double = 0
    var carbohydratesPerServing: Double = 0
    var fatPerServing: Double = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        title: String,
        servings: Int = 2,
        prepMinutes: Int = 0,
        category: String = "",
        imageURL: String = "",
        sourceURL: String = ""
    ) {
        let timestamp = Date()
        id = UUID()
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.servings = max(servings, 1)
        self.prepMinutes = max(prepMinutes, 0)
        self.category = category
        self.imageURL = imageURL
        self.sourceURL = sourceURL
        createdAt = timestamp
        updatedAt = timestamp
    }
}

@Model
final class RecipeIngredient {
    var id: UUID = UUID()
    var recipeID: UUID = UUID()
    var name: String = ""
    var amount: String = ""
    var unit: String = ""
    var position: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(recipeID: UUID, name: String = "", amount: String = "", unit: String = "", position: Int = 0) {
        let timestamp = Date()
        id = UUID()
        self.recipeID = recipeID
        self.name = name
        self.amount = amount
        self.unit = unit
        self.position = position
        createdAt = timestamp
        updatedAt = timestamp
    }
}

@Model
final class RecipeStep {
    var id: UUID = UUID()
    var recipeID: UUID = UUID()
    var instruction: String = ""
    var durationSeconds: Int = 0
    var position: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(recipeID: UUID, instruction: String = "", position: Int = 0, durationSeconds: Int = 0) {
        let timestamp = Date()
        id = UUID()
        self.recipeID = recipeID
        self.instruction = instruction
        self.durationSeconds = max(0, durationSeconds)
        self.position = position
        createdAt = timestamp
        updatedAt = timestamp
    }
}
