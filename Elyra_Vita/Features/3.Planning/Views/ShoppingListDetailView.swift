import SwiftUI
import SwiftData

// MARK: - ShoppingListDetailView

struct ShoppingListDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var allItems: [ShoppingListItem]

    let list: ShoppingList
    @State private var showingAddItem = false
    @State private var editingItem: ShoppingListItem?

    private var items: [ShoppingListItem] {
        allItems
            .filter { $0.listID == list.id }
            .sorted { $0.sortOrder < $1.sortOrder || $0.createdAt < $1.createdAt }
    }

    private var openItems: [ShoppingListItem] {
        items.filter { !$0.isCompleted }
    }

    private var completedItems: [ShoppingListItem] {
        items.filter(\.isCompleted)
    }

    var body: some View {
        List {
            if items.isEmpty {
                ContentUnavailableView(
                    "Noch keine Artikel",
                    systemImage: "cart",
                    description: Text("Füge deine ersten Einkäufe hinzu.")
                )
            } else {
                itemSection("Offen", items: openItems)
                itemSection("Erledigt", items: completedItems)
            }
        }
        .navigationTitle(list.name)
        .onAppear {
            removeCompletedItemsFromPreviousDays()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                removeCompletedItemsFromPreviousDays()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddItem = true
                } label: {
                    Label("Artikel hinzufügen", systemImage: "plus")
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !items.isEmpty {
                Label(
                    "Erledigte Artikel werden am Folgetag automatisch entfernt.",
                    systemImage: "info.circle"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(.thinMaterial)
            }
        }
        .sheet(isPresented: $showingAddItem) {
            ShoppingListItemEditorView(listID: list.id)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingItem) { item in
            ShoppingListItemEditorView(listID: list.id, item: item)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func itemSection(_ title: String, items: [ShoppingListItem]) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(items) { item in
                    Button {
                        item.update(isCompleted: !item.isCompleted)
                        list.updatedAt = .now
                        PersistenceErrorReporter.save(modelContext, operation: "Einkaufsartikel aktualisieren")
                    } label: {
                        itemRow(item)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            item.update(isCompleted: !item.isCompleted)
                            list.updatedAt = .now
                            PersistenceErrorReporter.save(modelContext, operation: "Einkaufsartikel aktualisieren")
                        } label: {
                            Label(item.isCompleted ? "Offen" : "Erledigt", systemImage: item.isCompleted ? "arrow.uturn.backward" : "checkmark")
                        }
                        .tint(.green)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            modelContext.delete(item)
                            PersistenceErrorReporter.save(modelContext, operation: "Einkaufsartikel löschen")
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button("Bearbeiten", systemImage: "pencil") {
                            editingItem = item
                        }
                        Button(item.isCompleted ? "Als offen markieren" : "Als erledigt markieren", systemImage: item.isCompleted ? "arrow.uturn.backward" : "checkmark") {
                            item.update(isCompleted: !item.isCompleted)
                            list.updatedAt = .now
                            PersistenceErrorReporter.save(modelContext, operation: "Einkaufsartikel aktualisieren")
                        }
                        Button("Löschen", systemImage: "trash", role: .destructive) {
                            modelContext.delete(item)
                            PersistenceErrorReporter.save(modelContext, operation: "Einkaufsartikel löschen")
                        }
                    }
                }
            }
        }
    }

    private func itemRow(_ item: ShoppingListItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(item.isCompleted ? .green : .secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                if !item.note.isEmpty {
                    Text(item.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
            Text("\(item.quantity.formatted(.number.precision(.fractionLength(0...2)))) \(item.unit)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func removeCompletedItemsFromPreviousDays() {
        let previousDayItems = allItems.filter {
            $0.listID == list.id && $0.shouldBeRemoved(on: .now)
        }

        guard !previousDayItems.isEmpty else { return }

        previousDayItems.forEach(modelContext.delete)
        list.updatedAt = .now
        PersistenceErrorReporter.save(modelContext, operation: "Erledigte Einkaufsartikel entfernen")
    }
}
