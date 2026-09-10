import SwiftUI

extension TodoListDetailView {
    func taskRow(_ task: TodoTask) -> some View {
        HStack(spacing: 12) {
            Button {
                toggleCompletion(for: task)
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
                dueDateView(for: task)
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
            Button("Bearbeiten", systemImage: "pencil") { editingTask = task }
            Button(
                task.isCompleted ? "Als offen markieren" : "Als erledigt markieren",
                systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark"
            ) {
                toggleCompletion(for: task)
            }
            Button("Löschen", systemImage: "trash", role: .destructive) {
                pendingTaskDeletion = task
            }
        }
    }

    @ViewBuilder
    func priorityIndicator(_ priority: Int) -> some View {
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

    @ViewBuilder
    func dueDateView(for task: TodoTask) -> some View {
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
}
