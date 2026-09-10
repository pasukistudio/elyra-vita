import PasukiUI
import SwiftData
import SwiftUI

enum PlanningArea: String, CaseIterable, Identifiable {
    case habits
    case todos
    case shopping

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .habits: "Gewohnheiten"
        case .todos: "Aufgaben"
        case .shopping: "Einkauf"
        }
    }
}

// MARK: - PlanningView

/// Einstieg in die Planung. Die Listenstruktur kann später für To-dos,
/// Gewohnheiten und geteilte Bereiche erweitert werden.
struct PlanningView: View {
    @Environment(\.elyraAccentColor) var accentColor
    @Environment(\.modelContext) var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \ShoppingList.updatedAt, order: .reverse) var shoppingLists: [ShoppingList]
    @Query var shoppingItems: [ShoppingListItem]
    @Query(sort: \TodoList.updatedAt, order: .reverse) var todoLists: [TodoList]
    @Query var todoTasks: [TodoTask]
    @Binding var showingNewList: Bool
    @Binding var showingNewTodoList: Bool
    @Binding var showingNewHabit: Bool
    @State var editingList: ShoppingList?
    @State var editingTodoList: TodoList?
    @State var pendingShoppingListDeletion: ShoppingList?
    @State var pendingTodoListDeletion: TodoList?
    @Binding private var selectedArea: PlanningArea
    @State private var isEditing = false

    init(
        selectedArea: Binding<PlanningArea> = .constant(.habits),
        showingNewList: Binding<Bool> = .constant(false),
        showingNewTodoList: Binding<Bool> = .constant(false),
        showingNewHabit: Binding<Bool> = .constant(false)
    ) {
        _selectedArea = selectedArea
        _showingNewList = showingNewList
        _showingNewTodoList = showingNewTodoList
        _showingNewHabit = showingNewHabit
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    Text(selectedArea.title)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    if selectedArea == .habits {
                        Button(isEditing ? "Fertig" : "Edit") {
                            isEditing.toggle()
                        }
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(accentColor.opacity(0.14), in: Capsule())
                        .accessibilityLabel(isEditing ? "Bearbeiten beenden" : "Gewohnheiten bearbeiten")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 14)

                areaPicker

                TabView(selection: $selectedArea) {
                    HabitsView(showingNewHabit: $showingNewHabit)
                        .tag(PlanningArea.habits)

                    todoPage
                        .tag(PlanningArea.todos)

                    shoppingPage
                        .tag(PlanningArea.shopping)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }

            ElyraFloatingActionButton(
                accessibilityLabel: addActionTitle,
                action: addAction
            )
            .padding(.trailing, 22)
            .padding(.bottom, 18)
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
        .alert(
            "Einkaufsliste löschen?",
            isPresented: shoppingListDeletionAlertIsPresented,
            presenting: pendingShoppingListDeletion
        ) { list in
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
        .alert(
            "To-do-Liste löschen?",
            isPresented: todoListDeletionAlertIsPresented,
            presenting: pendingTodoListDeletion
        ) { list in
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
        .appBackground()
        .task {
            removeCompletedShoppingItems()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                removeCompletedShoppingItems()
            }
        }
    }

    /// Entfernt erledigte Artikel beim Öffnen der Planung und beim
    /// Zurückkehren in die App, auch wenn die Detailansicht nicht neu geladen
    /// wurde.
    private func removeCompletedShoppingItems() {
        let itemsToRemove = shoppingItems.filter {
            $0.shouldBeRemoved(on: .now)
        }

        guard !itemsToRemove.isEmpty else { return }

        itemsToRemove.forEach(modelContext.delete)
        PersistenceErrorReporter.save(modelContext, operation: "Erledigte Einkaufsartikel entfernen")
    }

    private var areaPicker: some View {
        Picker("Planungsbereich", selection: $selectedArea) {
            ForEach(PlanningArea.allCases) { area in
                Text(area.title).tag(area)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .accessibilityLabel("Planungsbereich auswählen")
    }

    private var addActionTitle: String {
        switch selectedArea {
        case .habits: "Neue Gewohnheit"
        case .shopping: "Neue Einkaufsliste"
        case .todos: "Neue To-do-Liste"
        }
    }

    private var addAction: () -> Void {
        switch selectedArea {
        case .habits: { showingNewHabit = true }
        case .shopping: { showingNewList = true }
        case .todos: { showingNewTodoList = true }
        }
    }

    private var todoListDeletionAlertIsPresented: Binding<Bool> {
        Binding(
            get: { pendingTodoListDeletion != nil },
            set: {
                if !$0 {
                    pendingTodoListDeletion = nil
                }
            }
        )
    }

    private var shoppingListDeletionAlertIsPresented: Binding<Bool> {
        Binding(
            get: { pendingShoppingListDeletion != nil },
            set: {
                if !$0 {
                    pendingShoppingListDeletion = nil
                }
            }
        )
    }
}

struct PlanningEmptyState {
    let title: String
    let description: String
    let actionTitle: String
    let systemImage: String
    let color: Color
    let action: () -> Void
}
