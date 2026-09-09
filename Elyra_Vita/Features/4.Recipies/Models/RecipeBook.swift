import Foundation
import SwiftData

@Model
final class RecipeBook {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(name: String) {
        let timestamp = Date()
        id = UUID()
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        createdAt = timestamp
        updatedAt = timestamp
    }
}

@Model
final class RecipeBookMembership {
    var id: UUID = UUID()
    var recipeID: UUID = UUID()
    var bookID: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(recipeID: UUID, bookID: UUID) {
        let timestamp = Date()
        id = UUID()
        self.recipeID = recipeID
        self.bookID = bookID
        createdAt = timestamp
        updatedAt = timestamp
    }
}
