import SwiftUI

extension NutritionView {
    func entryRow(_ entry: NutritionEntry) -> some View {
        let isSelected = selectedEntryIDs.contains(ObjectIdentifier(entry))
        return HStack(spacing: 12) {
            if isSelectingEntries {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? accentColor : .secondary)
                    .font(.title3)
            }
            Image(systemName: entry.mealType.icon)
                .foregroundStyle(accentColor)
                .frame(width: 32, height: 32)
                .background(accentColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.foodName)
                    .font(.body.weight(.semibold))
                Text(
                    "\(entry.mealType.title) · "
                        + "\(entry.amount.formatted(.number.precision(.fractionLength(0)))) "
                        + displayUnit(for: entry.unit)
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(entry.calories, format: .number.precision(.fractionLength(0)))
                    .font(.body.weight(.semibold))
                Text("kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !isSelectingEntries {
                entryActionsMenu(for: entry)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isSelectingEntries else { return }
            let id = ObjectIdentifier(entry)
            if isSelected {
                selectedEntryIDs.remove(id)
            } else {
                selectedEntryIDs.insert(id)
            }
        }
    }

    private func entryActionsMenu(for entry: NutritionEntry) -> some View {
        Menu {
            Button(
                isFavorite(entry)
                    ? "Aus Favoriten entfernen"
                    : "Als Favorit markieren",
                systemImage: isFavorite(entry) ? "star.slash" : "star"
            ) {
                toggleFavorite(entry)
            }
            Button("Bearbeiten", systemImage: "pencil") {
                editingEntry = entry
            }
            Button("Löschen", systemImage: "trash", role: .destructive) {
                deletingEntry = entry
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel("Aktionen für \(entry.foodName)")
    }
}
