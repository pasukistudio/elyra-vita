import SwiftData
import SwiftUI

struct TodoListDetailView: View {
    @Environment(\.modelContext) var modelContext
    @Query private var allTasks: [TodoTask]
    @State private var showingNewTask = false
    @State var editingTask: TodoTask?
    @State private var inlineTitle = ""
    @State private var completedTasksExpanded = true
    @State var pendingTaskDeletion: TodoTask?
    @FocusState private var inlineTitleFocused: Bool

    let list: TodoList

    init(list: TodoList) {
        self.list = list
    }

    private var tasks: [TodoTask] {
        allTasks.filter { $0.listID == list.id }
    }

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

    func toggleCompletion(for task: TodoTask) {
        task.update(isCompleted: !task.isCompleted)
        list.updatedAt = .now
        PersistenceErrorReporter.save(modelContext, operation: "To-do aktualisieren")
    }

    private var deletionAlertIsPresented: Binding<Bool> {
        Binding(
            get: { pendingTaskDeletion != nil },
            set: {
                if !$0 {
                    pendingTaskDeletion = nil
                }
            }
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
}
