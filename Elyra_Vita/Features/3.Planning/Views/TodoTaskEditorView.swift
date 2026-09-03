import SwiftUI
import SwiftData

struct TodoTaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let list: TodoList
    private let task: TodoTask?
    @State private var title: String
    @State private var note: String
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var priority: Int

    init(list: TodoList, task: TodoTask? = nil) {
        self.list = list
        self.task = task
        _title = State(initialValue: task?.title ?? "")
        _note = State(initialValue: task?.note ?? "")
        _hasDueDate = State(initialValue: task?.dueDate != nil)
        _dueDate = State(initialValue: task?.dueDate ?? .now)
        _priority = State(initialValue: task?.priority ?? 1)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Aufgabe") {
                    TextField("Titel", text: $title)
                    TextField("Notiz (optional)", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Planung") {
                    Picker("Priorität", selection: $priority) {
                        Text("Niedrig").tag(0)
                        Text("Normal").tag(1)
                        Text("Hoch").tag(2)
                    }
                    Toggle("Fälligkeitsdatum", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Fällig am", selection: $dueDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle(task == nil ? "Neue Aufgabe" : "Aufgabe bearbeiten")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(task == nil ? "Anlegen" : "Speichern") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        if let task {
            task.update(
                title: trimmedTitle,
                note: note,
                dueDate: hasDueDate ? dueDate : nil,
                priority: priority
            )
        } else {
            modelContext.insert(
                TodoTask(
                    listID: list.id,
                    title: trimmedTitle,
                    note: note,
                    dueDate: hasDueDate ? dueDate : nil,
                    priority: priority
                )
            )
            list.updatedAt = .now
        }
        if PersistenceErrorReporter.save(modelContext, operation: "To-do speichern") {
            dismiss()
        }
    }
}
