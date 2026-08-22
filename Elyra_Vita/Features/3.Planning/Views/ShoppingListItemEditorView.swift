import SwiftUI
import SwiftData

// MARK: - ShoppingListItemEditorView

struct ShoppingListItemEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [ShoppingListItem]
    @Query private var itemHistory: [ShoppingListItemHistory]

    let listID: UUID
    let item: ShoppingListItem?
    @State private var name: String
    @State private var quantityText: String
    @State private var unit: String
    @State private var note: String

    private let units = ["Stück", "g", "kg", "ml", "l", "Packung"]

    private var nameSuggestions: [String] {
        let query = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        var seenNames = Set<String>()
        let activeNames = allItems
            .filter { candidate in
                candidate.listID == listID &&
                candidate.id != item?.id &&
                candidate.name.localizedCaseInsensitiveContains(query) &&
                candidate.name.compare(query, options: .caseInsensitive) != .orderedSame
            }
            .map(\.name)

        let historyNames = itemHistory
            .filter { candidate in
                candidate.listID == listID &&
                candidate.name.localizedCaseInsensitiveContains(query) &&
                candidate.name.compare(query, options: .caseInsensitive) != .orderedSame
            }
            .sorted { $0.lastUsedAt > $1.lastUsedAt }
            .map(\.name)

        return (historyNames + activeNames)
            .compactMap { candidate in
                let key = candidate.folding(
                    options: [.caseInsensitive, .diacriticInsensitive],
                    locale: .current
                )
                guard seenNames.insert(key).inserted else { return nil }
                return candidate
            }
            .prefix(5)
            .map { $0 }
    }

    init(listID: UUID, item: ShoppingListItem? = nil) {
        self.listID = listID
        self.item = item
        _name = State(initialValue: item?.name ?? "")
        _quantityText = State(initialValue: item.map { Self.number($0.quantity) } ?? "1")
        _unit = State(initialValue: item?.unit ?? "Stück")
        _note = State(initialValue: item?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Artikel") {
                    TextField("Was möchtest du einkaufen?", text: $name)
                    HStack {
                        TextField("Menge", text: $quantityText)
                            .keyboardType(.decimalPad)
                        Picker("Einheit", selection: $unit) {
                            ForEach(units, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                    }
                    TextField("Notiz (optional)", text: $note)
                }

                if !nameSuggestions.isEmpty {
                    Section("Frühere Einträge") {
                        ForEach(nameSuggestions, id: \.self) { suggestion in
                            Button {
                                name = suggestion
                            } label: {
                                Label(suggestion, systemImage: "clock.arrow.circlepath")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle(item == nil ? "Artikel hinzufügen" : "Artikel bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(item == nil ? "Hinzufügen" : "Speichern") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let quantity = Double(quantityText.replacingOccurrences(of: ",", with: ".")) ?? 1

        if let item {
            item.update(name: trimmedName, quantity: max(0, quantity), unit: unit, note: note)
        } else {
            modelContext.insert(
                ShoppingListItem(
                    listID: listID,
                    name: trimmedName,
                    quantity: max(0, quantity),
                    unit: unit,
                    note: note
                )
            )
        }

        remember(trimmedName)

        try? modelContext.save()
        dismiss()
    }

    private func remember(_ name: String) {
        let normalizedName = name.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )

        if let existing = itemHistory.first(where: {
            $0.listID == listID &&
            $0.name.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            ) == normalizedName
        }) {
            existing.markUsed()
        } else {
            modelContext.insert(ShoppingListItemHistory(listID: listID, name: name))
        }
    }

    private static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}
