import SwiftUI
import SwiftData

// MARK: - ShoppingListEditorView

struct ShoppingListEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let list: ShoppingList?
    @State private var name: String

    init(list: ShoppingList? = nil) {
        self.list = list
        _name = State(initialValue: list?.name ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Liste") {
                    TextField("Name der Einkaufsliste", text: $name)
                }
            }
            .navigationTitle(list == nil ? "Neue Liste" : "Liste bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { save() }
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
            modelContext.insert(ShoppingList(name: trimmedName))
        }

        try? modelContext.save()
        dismiss()
    }
}
