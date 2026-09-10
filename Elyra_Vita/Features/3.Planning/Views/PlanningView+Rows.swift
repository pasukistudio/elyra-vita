import SwiftData
import SwiftUI

extension PlanningView {
    func emptyPlanningCard(_ state: PlanningEmptyState) -> some View {
        VStack(spacing: 14) {
            Image(systemName: state.systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(state.color)
                .frame(width: 58, height: 58)
                .background(state.color.opacity(0.12), in: Circle())
            VStack(spacing: 5) {
                Text(state.title).font(.headline)
                Text(state.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button(action: state.action) {
                Label(state.actionTitle, systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(state.color)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
    }

    func listRow(_ list: ShoppingList) -> some View {
        let items = shoppingItems.filter { $0.listID == list.id }
        let openCount = items.filter { !$0.isCompleted }.count
        return HStack(spacing: 12) {
            Image(systemName: "cart.fill")
                .foregroundStyle(.blue)
                .frame(width: 32, height: 32)
                .background(.blue.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(list.name).font(.headline)
                Text(openCount == 0 && !items.isEmpty ? "Alles erledigt" : "\(openCount) offene Artikel")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(items.count)").foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    func todoListRow(_ list: TodoList) -> some View {
        let tasks = todoTasks.filter { $0.listID == list.id }
        let openCount = tasks.filter { !$0.isCompleted }.count
        return HStack(spacing: 12) {
            Image(systemName: "checklist")
                .foregroundStyle(.purple)
                .frame(width: 32, height: 32)
                .background(.purple.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(list.name).font(.headline)
                Text(openCount == 0 && !tasks.isEmpty ? "Alles erledigt" : "\(openCount) offene Aufgaben")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(tasks.count)").foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    func delete(_ list: ShoppingList) {
        for item in shoppingItems where item.listID == list.id {
            modelContext.delete(item)
        }
        modelContext.delete(list)
        PersistenceErrorReporter.save(modelContext, operation: "Einkaufsliste löschen")
    }

    func delete(_ list: TodoList) {
        for task in todoTasks where task.listID == list.id {
            modelContext.delete(task)
        }
        modelContext.delete(list)
        PersistenceErrorReporter.save(modelContext, operation: "To-do-Liste löschen")
    }
}
