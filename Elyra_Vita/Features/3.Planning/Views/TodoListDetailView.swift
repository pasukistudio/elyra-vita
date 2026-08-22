import SwiftUI
import SwiftData

struct TodoListDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allTasks: [TodoTask]
    @State private var showingNewTask = false
    @State private var editingTask: TodoTask?

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
                    return first.createdAt < second.createdAt
                }
            }
    }
    private var completedTasks: [TodoTask] { tasks.filter(\.isCompleted) }

    var body: some View {
        List {
            if openTasks.isEmpty && completedTasks.isEmpty {
                ContentUnavailableView(
                    "Noch keine Aufgaben",
                    systemImage: "checklist",
                    description: Text("Lege deine erste Aufgabe für diese Liste an.")
                )
            } else {
                Section("Offen") {
                    if openTasks.isEmpty {
                        Text("Keine offenen Aufgaben")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(openTasks) { task in
                            taskRow(task)
                        }
                    }
                }

                if !completedTasks.isEmpty {
                    Section("Erledigt") {
                        ForEach(completedTasks) { task in
                            taskRow(task)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(list.name)
        .toolbar {
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
    }

    private func taskRow(_ task: TodoTask) -> some View {
        HStack(spacing: 12) {
            Button {
                task.update(isCompleted: !task.isCompleted)
                list.updatedAt = .now
                try? modelContext.save()
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
                    Label {
                        Text(dueDate, style: .date)
                    } icon: {
                        Image(systemName: "calendar")
                    }
                        .font(.caption2)
                        .foregroundStyle(dueDate < Calendar.current.startOfDay(for: .now) ? .red : .secondary)
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
                modelContext.delete(task)
                try? modelContext.save()
            } label: {
                Label("Löschen", systemImage: "trash")
            }
        }
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
