import SwiftUI
import SwiftData
import PasukiUI

// MARK: - PlanningView

/// Einstieg in die Planung. Die Listenstruktur kann später für To-dos,
/// Gewohnheiten und geteilte Bereiche erweitert werden.
struct PlanningView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShoppingList.updatedAt, order: .reverse) private var shoppingLists: [ShoppingList]
    @Query private var shoppingItems: [ShoppingListItem]
    @Query(sort: \TodoList.updatedAt, order: .reverse) private var todoLists: [TodoList]
    @Query private var todoTasks: [TodoTask]
    @Binding private var showingNewList: Bool
    @Binding private var showingNewTodoList: Bool
    @State private var editingList: ShoppingList?
    @State private var editingTodoList: TodoList?

    init(
        showingNewList: Binding<Bool> = .constant(false),
        showingNewTodoList: Binding<Bool> = .constant(false)
    ) {
        self._showingNewList = showingNewList
        self._showingNewTodoList = showingNewTodoList
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if shoppingLists.isEmpty {
                        VStack(spacing: 14) {
                            ContentUnavailableView(
                                "Noch keine Einkaufsliste",
                                systemImage: "cart",
                                description: Text("Lege eine Liste an, um deine Einkäufe zu planen.")
                            )

                            Button {
                                showingNewList = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus")
                                    Text("Neue Einkaufsliste anlegen")
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .frame(maxWidth: 280)
                        }
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(shoppingLists) { list in
                            NavigationLink {
                                ShoppingListDetailView(list: list)
                            } label: {
                                listRow(list)
                            }
                            .swipeActions {
                                Button("Bearbeiten", systemImage: "pencil") {
                                    editingList = list
                                }
                                .tint(.blue)
                                Button(role: .destructive) {
                                    delete(list)
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    Text("Einkaufslisten")
                }

                Section {
                    if todoLists.isEmpty {
                        VStack(spacing: 12) {
                            ContentUnavailableView(
                                "Noch keine To-do-Liste",
                                systemImage: "checklist",
                                description: Text("Lege eine Liste für deine Aufgaben an.")
                            )

                            Button {
                                showingNewTodoList = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus")
                                    Text("Neue To-do-Liste anlegen")
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .frame(maxWidth: 280)
                        }
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(todoLists) { list in
                            NavigationLink {
                                TodoListDetailView(list: list)
                            } label: {
                                todoListRow(list)
                            }
                            .swipeActions {
                                Button("Bearbeiten", systemImage: "pencil") {
                                    editingTodoList = list
                                }
                                .tint(.blue)
                                Button(role: .destructive) {
                                    delete(list)
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button("Bearbeiten", systemImage: "pencil") {
                                    editingTodoList = list
                                }
                                Button("Löschen", systemImage: "trash", role: .destructive) {
                                    delete(list)
                                }
                            }
                        }
                    }
                } header: {
                    Text("To-do-Listen")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Planung")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewList = true
                    } label: {
                        Label("Neue Einkaufsliste", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewList) {
                ShoppingListEditorView()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $editingList) { list in
                ShoppingListEditorView(list: list)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingNewTodoList) {
                TodoListEditorView()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $editingTodoList) { list in
                TodoListEditorView(list: list)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
        .appBackground()
    }

    private func listRow(_ list: ShoppingList) -> some View {
        let items = shoppingItems.filter { $0.listID == list.id }
        let openCount = items.filter { !$0.isCompleted }.count

        return HStack(spacing: 12) {
            Image(systemName: "cart.fill")
                .foregroundStyle(.blue)
                .frame(width: 32, height: 32)
                .background(.blue.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(list.name)
                    .font(.headline)
                Text(openCount == 0 && !items.isEmpty ? "Alles erledigt" : "\(openCount) offene Artikel")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Text("\(items.count)")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func delete(_ list: ShoppingList) {
        for item in shoppingItems where item.listID == list.id {
            modelContext.delete(item)
        }
        modelContext.delete(list)
        try? modelContext.save()
    }

    private func todoListRow(_ list: TodoList) -> some View {
        let tasks = todoTasks.filter { $0.listID == list.id }
        let openCount = tasks.filter { !$0.isCompleted }.count

        return HStack(spacing: 12) {
            Image(systemName: "checklist")
                .foregroundStyle(.purple)
                .frame(width: 32, height: 32)
                .background(.purple.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(list.name)
                    .font(.headline)
                Text(openCount == 0 && !tasks.isEmpty ? "Alles erledigt" : "\(openCount) offene Aufgaben")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Text("\(tasks.count)")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func delete(_ list: TodoList) {
        for task in todoTasks where task.listID == list.id {
            modelContext.delete(task)
        }
        modelContext.delete(list)
        try? modelContext.save()
    }
}
