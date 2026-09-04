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
    @Query(sort: \Habit.updatedAt, order: .reverse) private var habits: [Habit]
    @Binding private var showingNewList: Bool
    @Binding private var showingNewTodoList: Bool
    @Binding private var showingNewHabit: Bool
    @State private var editingList: ShoppingList?
    @State private var editingTodoList: TodoList?
    @State private var pendingShoppingListDeletion: ShoppingList?
    @State private var pendingTodoListDeletion: TodoList?

    private var activeHabits: [Habit] { habits.filter { !$0.isArchived } }

    init(
        showingNewList: Binding<Bool> = .constant(false),
        showingNewTodoList: Binding<Bool> = .constant(false),
        showingNewHabit: Binding<Bool> = .constant(false)
    ) {
        self._showingNewList = showingNewList
        self._showingNewTodoList = showingNewTodoList
        self._showingNewHabit = showingNewHabit
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if activeHabits.isEmpty {
                        emptyPlanningCard(
                            title: "Noch keine Gewohnheiten",
                            description: "Lege deine erste Gewohnheit an.",
                            actionTitle: "Gewohnheit anlegen",
                            systemImage: "checkmark.circle.fill",
                            color: .green
                        ) {
                            showingNewHabit = true
                        }
                    } else {
                        NavigationLink {
                            HabitsView(showingNewHabit: $showingNewHabit)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .frame(width: 32, height: 32)
                                    .background(.green.opacity(0.12), in: Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Gewohnheiten").font(.headline)
                                    Text("\(activeHabits.count) aktive Gewohnheiten")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: { Text("Gewohnheiten") }

                Section {
                    if shoppingLists.isEmpty {
                        emptyPlanningCard(
                            title: "Noch keine Einkaufsliste",
                            description: "Lege eine Liste an, um deine Einkäufe zu planen.",
                            actionTitle: "Einkaufsliste anlegen",
                            systemImage: "cart.fill",
                            color: .blue
                        ) {
                            showingNewList = true
                        }
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
                                    pendingShoppingListDeletion = list
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button("Bearbeiten", systemImage: "pencil") {
                                    editingList = list
                                }
                                Button("Löschen", systemImage: "trash", role: .destructive) {
                                    pendingShoppingListDeletion = list
                                }
                            }
                        }
                    }
                } header: {
                    Text("Einkaufslisten")
                }

                Section {
                    if todoLists.isEmpty {
                        emptyPlanningCard(
                            title: "Noch keine To-do-Liste",
                            description: "Lege eine Liste für deine Aufgaben an.",
                            actionTitle: "To-do-Liste anlegen",
                            systemImage: "checklist",
                            color: .purple
                        ) {
                            showingNewTodoList = true
                        }
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
                                    pendingTodoListDeletion = list
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button("Bearbeiten", systemImage: "pencil") {
                                    editingTodoList = list
                                }
                                Button("Löschen", systemImage: "trash", role: .destructive) {
                                    pendingTodoListDeletion = list
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
            .alert("Einkaufsliste löschen?", isPresented: shoppingListDeletionAlertIsPresented, presenting: pendingShoppingListDeletion) { list in
                Button("Löschen", role: .destructive) {
                    delete(list)
                    pendingShoppingListDeletion = nil
                }
                Button("Abbrechen", role: .cancel) {
                    pendingShoppingListDeletion = nil
                }
            } message: { list in
                Text("\"\(list.name)\" und alle enthaltenen Artikel werden dauerhaft entfernt.")
            }
            .alert("To-do-Liste löschen?", isPresented: todoListDeletionAlertIsPresented, presenting: pendingTodoListDeletion) { list in
                Button("Löschen", role: .destructive) {
                    delete(list)
                    pendingTodoListDeletion = nil
                }
                Button("Abbrechen", role: .cancel) {
                    pendingTodoListDeletion = nil
                }
            } message: { list in
                Text("\"\(list.name)\" und alle enthaltenen Aufgaben werden dauerhaft entfernt.")
            }
        }
        .appBackground()
    }

    private func emptyPlanningCard(
        title: String,
        description: String,
        actionTitle: String,
        systemImage: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 58, height: 58)
                .background(color.opacity(0.12), in: Circle())

            VStack(spacing: 5) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: action) {
                Label(actionTitle, systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(color)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
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
        PersistenceErrorReporter.save(modelContext, operation: "Einkaufsliste löschen")
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
        PersistenceErrorReporter.save(modelContext, operation: "To-do-Liste löschen")
    }

    private var todoListDeletionAlertIsPresented: Binding<Bool> {
        Binding(
            get: { pendingTodoListDeletion != nil },
            set: { if !$0 { pendingTodoListDeletion = nil } }
        )
    }

    private var shoppingListDeletionAlertIsPresented: Binding<Bool> {
        Binding(
            get: { pendingShoppingListDeletion != nil },
            set: { if !$0 { pendingShoppingListDeletion = nil } }
        )
    }
}
