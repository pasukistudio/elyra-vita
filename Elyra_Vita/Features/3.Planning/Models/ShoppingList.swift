import Foundation
import SwiftData

// MARK: - ShoppingList

/// Eine persönliche Einkaufsliste. Die Freigabefelder sind bereits Teil des
/// Modells, damit spätere CloudKit-Einladungen ohne Modellbruch ergänzt werden.
@Model
final class ShoppingList {
    var id: UUID = UUID()
    var name: String = ""
    var ownerIdentifier: String = ""
    var shareIdentifier: String = ""
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(name: String) {
        let timestamp = Date()
        self.id = UUID()
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = timestamp
        self.updatedAt = timestamp
    }

    func update(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        self.name = trimmedName
        updatedAt = .now
    }
}

// MARK: - ShoppingListItem

/// Ein Eintrag einer Einkaufsliste. Die Zuordnung erfolgt bewusst über eine
/// stabile ID statt über eine SwiftData-Beziehung, damit CloudKit-Freigaben
/// und spätere Konfliktauflösung flexibel bleiben.
@Model
final class ShoppingListItem {
    var id: UUID = UUID()
    var listID: UUID = UUID()
    var name: String = ""
    var quantity: Double = 1
    var unit: String = "Stück"
    var note: String = ""
    var isCompleted: Bool = false
    var completedAt: Date?
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        listID: UUID,
        name: String,
        quantity: Double = 1,
        unit: String = "Stück",
        note: String = "",
        sortOrder: Int = 0
    ) {
        let timestamp = Date()
        self.id = UUID()
        self.listID = listID
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.quantity = max(0, quantity)
        self.unit = unit
        self.note = note
        self.sortOrder = sortOrder
        self.createdAt = timestamp
        self.updatedAt = timestamp
    }

    func update(
        name: String? = nil,
        quantity: Double? = nil,
        unit: String? = nil,
        note: String? = nil,
        isCompleted: Bool? = nil
    ) {
        if let name {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedName.isEmpty { self.name = trimmedName }
        }
        if let quantity, quantity >= 0 { self.quantity = quantity }
        if let unit { self.unit = unit }
        if let note { self.note = note }
        if let isCompleted {
            self.isCompleted = isCompleted
            completedAt = isCompleted ? .now : nil
        }
        updatedAt = .now
    }

    func shouldBeRemoved(on date: Date, calendar: Calendar = .current) -> Bool {
        guard isCompleted, let completedAt else { return false }
        return completedAt < calendar.startOfDay(for: date)
    }
}

// MARK: - ShoppingListItemHistory

/// Behält Artikelnamen für spätere Vorschläge, auch wenn der aktive Eintrag
/// aus der Einkaufsliste entfernt wurde.
@Model
final class ShoppingListItemHistory {
    var id: UUID = UUID()
    var listID: UUID = UUID()
    var name: String = ""
    var lastUsedAt: Date = Date()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(listID: UUID, name: String) {
        let timestamp = Date()
        self.id = UUID()
        self.listID = listID
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.lastUsedAt = timestamp
        self.createdAt = timestamp
        self.updatedAt = timestamp
    }

    func markUsed() {
        let timestamp = Date()
        lastUsedAt = timestamp
        updatedAt = timestamp
    }
}
