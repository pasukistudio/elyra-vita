import SwiftUI

extension PlanningView {
    var shoppingPage: some View {
        List {
            if shoppingLists.isEmpty {
                emptyPlanningCard(PlanningEmptyState(
                    title: "Noch keine Einkaufsliste",
                    description: "Lege eine Liste an, um deine Einkäufe zu planen.",
                    actionTitle: "Einkaufsliste anlegen",
                    systemImage: "cart.fill",
                    color: .blue,
                    action: { showingNewList = true }
                ))
            } else {
                ForEach(shoppingLists) { list in
                    NavigationLink { ShoppingListDetailView(list: list) } label: { listRow(list) }
                        .swipeActions {
                            Button("Bearbeiten", systemImage: "pencil") { editingList = list }.tint(.blue)
                            Button(role: .destructive) { pendingShoppingListDeletion = list } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button("Bearbeiten", systemImage: "pencil") { editingList = list }
                            Button("Löschen", systemImage: "trash", role: .destructive) {
                                pendingShoppingListDeletion = list
                            }
                        }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    var todoPage: some View {
        List {
            if todoLists.isEmpty {
                emptyPlanningCard(PlanningEmptyState(
                    title: "Noch keine To-do-Liste",
                    description: "Lege eine Liste für deine Aufgaben an.",
                    actionTitle: "To-do-Liste anlegen",
                    systemImage: "checklist",
                    color: .purple,
                    action: { showingNewTodoList = true }
                ))
            } else {
                ForEach(todoLists) { list in
                    NavigationLink { TodoListDetailView(list: list) } label: { todoListRow(list) }
                        .swipeActions {
                            Button("Bearbeiten", systemImage: "pencil") { editingTodoList = list }.tint(.purple)
                            Button(role: .destructive) { pendingTodoListDeletion = list } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button("Bearbeiten", systemImage: "pencil") { editingTodoList = list }
                            Button("Löschen", systemImage: "trash", role: .destructive) {
                                pendingTodoListDeletion = list
                            }
                        }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
