import SwiftUI

struct HabitCardView: View {
    let habit: Habit
    let selectedDate: Date
    let completionDays: [Date]
    let isCompleted: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var isDue: Bool {
        habit.isDue(on: selectedDate, completionDays: completionDays)
    }

    private var streak: Int {
        habit.currentStreak(on: selectedDate, completionDays: completionDays)
    }

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onToggle) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        isCompleted
                            ? AnyShapeStyle(.green)
                            : (isDue ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tertiary))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!isDue)

            VStack(alignment: .leading, spacing: 7) {
                Text(habit.name)
                    .font(.headline)
                    .strikethrough(isCompleted)
                    .foregroundStyle(isCompleted ? .secondary : .primary)
                HStack(spacing: 6) {
                    Label(habit.recurrenceText, systemImage: "repeat")
                    Text("·")
                    Label(habit.reminderTimeText, systemImage: "bell")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            VStack(spacing: 5) {
                Circle()
                    .fill(isDue ? Color.orange.opacity(0.14) : Color.secondary.opacity(0.10))
                    .frame(width: 34, height: 34)
                    .overlay {
                        Image(systemName: isDue ? "bell.fill" : "calendar")
                            .font(.caption)
                            .foregroundStyle(isDue ? .orange : .secondary)
                    }
                if streak > 0 {
                    Label("\(streak)", systemImage: "flame.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                        .accessibilityLabel("\(streak) in Folge")
                }
            }
        }
        .padding(16)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .contentShape(Rectangle())
        .contextMenu {
            Button("Bearbeiten", systemImage: "pencil", action: onEdit)
            Button("Löschen", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}
