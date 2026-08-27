import SwiftUI
import SwiftData

struct TodoListEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let list: TodoList?
    @State private var name: String

    init(list: TodoList? = nil) {
        self.list = list
        _name = State(initialValue: list?.name ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name der To-do-Liste", text: $name)
            }
            .navigationTitle(list == nil ? "Neue To-do-Liste" : "Liste bearbeiten")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(list == nil ? "Anlegen" : "Speichern") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        if let list {
            list.update(name: trimmedName)
        } else {
            modelContext.insert(TodoList(name: trimmedName))
        }
        try? modelContext.save()
        dismiss()
    }
}
