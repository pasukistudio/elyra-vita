import Foundation
import SwiftData

// MARK: - TodoList

@Model
final class TodoList {
    var id: UUID = UUID()
    var name: String = ""
    var ownerIdentifier: String = ""
    var shareIdentifier: String = ""
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(name: String) {
        let timestamp = Date()
        id = UUID()
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        createdAt = timestamp
        updatedAt = timestamp
    }

    func update(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        self.name = trimmedName
        updatedAt = .now
    }
}

// MARK: - TodoTask

@Model
final class TodoTask {
    var id: UUID = UUID()
    var listID: UUID = UUID()
    var title: String = ""
    var note: String = ""
    var dueDate: Date?
    var priority: Int = 1
    var isCompleted: Bool = false
    var completedAt: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        listID: UUID,
        title: String,
        note: String = "",
        dueDate: Date? = nil,
        priority: Int = 1
    ) {
        let timestamp = Date()
        id = UUID()
        self.listID = listID
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.note = note
        self.dueDate = dueDate
        self.priority = min(max(priority, 0), 2)
        createdAt = timestamp
        updatedAt = timestamp
    }

    func update(
        title: String? = nil,
        note: String? = nil,
        dueDate: Date?? = nil,
        priority: Int? = nil,
        isCompleted: Bool? = nil
    ) {
        if let title {
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedTitle.isEmpty { self.title = trimmedTitle }
        }
        if let note { self.note = note }
        if let dueDate { self.dueDate = dueDate }
        if let priority { self.priority = min(max(priority, 0), 2) }
        if let isCompleted {
            self.isCompleted = isCompleted
            completedAt = isCompleted ? .now : nil
        }
        updatedAt = .now
    }
}
