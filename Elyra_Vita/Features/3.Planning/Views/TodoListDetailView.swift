import SwiftUI
import SwiftData

struct TodoListDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allTasks: [TodoTask]
    @State private var showingNewTask = false
    @State private var editingTask: TodoTask?
    @State private var inlineTitle = ""
    @State private var completedTasksExpanded = true
    @State private var pendingTaskDeletion: TodoTask?
    @FocusState private var inlineTitleFocused: Bool

    let list: TodoList

    init(list: TodoList) {
        self.list = list
    }

    private var tasks: [TodoTask] { allTasks.filter { $0.listID == list.id } }
    private var openTasks: [TodoTask] {
        tasks
            .filter { !$0.isCompleted }
            .sorted { first, second in
                switch (first.dueDate, second.dueDate) {
                case let (firstDate?, secondDate?):
                    return firstDate < secondDate
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return first.sortOrder == second.sortOrder
                        ? first.createdAt < second.createdAt
                        : first.sortOrder < second.sortOrder
                }
            }
    }
    private var completedTasks: [TodoTask] {
        tasks
            .filter(\.isCompleted)
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    var body: some View {
        List {
            Section("Offen (\(openTasks.count))") {
                inlineTaskEntry

                if openTasks.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Aufgaben",
                        systemImage: "checklist",
                        description: Text("Lege deine erste Aufgabe direkt oben an.")
                    )
                } else {
                    ForEach(openTasks) { task in
                        taskRow(task)
                    }
                    .onMove(perform: moveOpenTasks)
                }
            }

            if !completedTasks.isEmpty {
                Section {
                    if completedTasksExpanded {
                        ForEach(completedTasks) { task in
                            taskRow(task)
                        }
                    }
                } header: {
                    Button {
                        withAnimation {
                            completedTasksExpanded.toggle()
                        }
                    } label: {
                        HStack {
                            Text("Erledigt (\(completedTasks.count))")
                            Spacer()
                            Image(systemName: completedTasksExpanded ? "chevron.up" : "chevron.down")
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(list.name)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNewTask = true
                } label: {
                    Label("Neue Aufgabe", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewTask) {
            TodoTaskEditorView(list: list)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingTask) { task in
            TodoTaskEditorView(list: list, task: task)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("Aufgabe löschen?", isPresented: deletionAlertIsPresented, presenting: pendingTaskDeletion) { task in
            Button("Löschen", role: .destructive) {
                modelContext.delete(task)
                PersistenceErrorReporter.save(modelContext, operation: "To-do löschen")
                pendingTaskDeletion = nil
            }
            Button("Abbrechen", role: .cancel) {
                pendingTaskDeletion = nil
            }
        } message: { task in
            Text("\"\(task.title)\" wird dauerhaft aus dieser Liste entfernt.")
        }
    }

    private var inlineTaskEntry: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.tint)

            TextField("Aufgabe hinzufügen", text: $inlineTitle)
                .focused($inlineTitleFocused)
                .submitLabel(.done)
                .onSubmit(addInlineTask)

            if !inlineTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button("Hinzufügen", systemImage: "arrow.up.circle.fill", action: addInlineTask)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.tint)
                    .accessibilityLabel("Aufgabe hinzufügen")
            }
        }
        .padding(.vertical, 4)
    }

    private func addInlineTask() {
        let trimmedTitle = inlineTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        modelContext.insert(TodoTask(listID: list.id, title: trimmedTitle))
        list.updatedAt = .now
        PersistenceErrorReporter.save(modelContext, operation: "To-do hinzufügen")
        inlineTitle = ""
        inlineTitleFocused = true
    }

    private func taskRow(_ task: TodoTask) -> some View {
        HStack(spacing: 12) {
            Button {
                task.update(isCompleted: !task.isCompleted)
                list.updatedAt = .now
                PersistenceErrorReporter.save(modelContext, operation: "To-do aktualisieren")
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                if !task.note.isEmpty {
                    Text(task.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let dueDate = task.dueDate, !task.isCompleted {
                    let isOverdue = dueDate < Calendar.current.startOfDay(for: .now)
                    Label {
                        if isOverdue {
                            Text("Überfällig")
                        } else {
                            Text(dueDate, style: .date)
                        }
                    } icon: {
                        Image(systemName: isOverdue ? "exclamationmark.triangle.fill" : "calendar")
                    }
                    .font(.caption2.weight(isOverdue ? .semibold : .regular))
                    .foregroundStyle(isOverdue ? .red : .secondary)
                }
            }

            Spacer()
            priorityIndicator(task.priority)
        }
        .contentShape(Rectangle())
        .onTapGesture { editingTask = task }
        .swipeActions {
            Button("Bearbeiten", systemImage: "pencil") { editingTask = task }
                .tint(.blue)
            Button(role: .destructive) {
                pendingTaskDeletion = task
            } label: {
                Label("Löschen", systemImage: "trash")
            }
        }
        .contextMenu {
            Button("Bearbeiten", systemImage: "pencil") {
                editingTask = task
            }
            Button(
                task.isCompleted ? "Als offen markieren" : "Als erledigt markieren",
                systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark"
            ) {
                task.update(isCompleted: !task.isCompleted)
                list.updatedAt = .now
                PersistenceErrorReporter.save(modelContext, operation: "To-do aktualisieren")
            }
            Button("Löschen", systemImage: "trash", role: .destructive) {
                pendingTaskDeletion = task
            }
        }
    }

    private var deletionAlertIsPresented: Binding<Bool> {
        Binding(
            get: { pendingTaskDeletion != nil },
            set: { if !$0 { pendingTaskDeletion = nil } }
        )
    }

    private func moveOpenTasks(from source: IndexSet, to destination: Int) {
        var reordered = openTasks
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, task) in reordered.enumerated() {
            task.sortOrder = index
            task.updatedAt = .now
        }
        list.updatedAt = .now
        PersistenceErrorReporter.save(modelContext, operation: "To-do sortieren")
    }

    @ViewBuilder
    private func priorityIndicator(_ priority: Int) -> some View {
        switch priority {
        case 2:
            Image(systemName: "exclamationmark.2")
                .foregroundStyle(.red)
        case 0:
            Image(systemName: "arrow.down")
                .foregroundStyle(.secondary)
        default:
            EmptyView()
        }
    }
}
