import SwiftUI
import SwiftData

// MARK: - FavoritesView

/// Eigene Übersicht für favorisierte Lebensmittel.
struct FavoritesView: View {

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \FavoriteFood.updatedAt, order: .reverse)
    private var favoriteFoods: [FavoriteFood]

    let selectedDate: Date
    let accentColor: Color

    @State private var selectedFood: NutritionFood?
    @State private var errorMessage: String?

    var body: some View {
        List {
            if favoriteFoods.isEmpty {
                ContentUnavailableView(
                    "Noch keine Favoriten",
                    systemImage: "star",
                    description: Text("Markiere Lebensmittel über das Drei-Punkte-Menü als Favorit.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(favoriteFoods) { favorite in
                    Button {
                        selectedFood = favorite.nutritionFood
                    } label: {
                        favoriteRow(favorite)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Aus Favoriten entfernen", systemImage: "star.slash") {
                            removeFavorite(favorite)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Meine Favoriten")
        .sheet(item: $selectedFood) { food in
            AddNutritionEntryView(
                selectedDate: selectedDate,
                accentColor: accentColor,
                initialFood: food
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(.systemBackground))
        }
        .alert("Favorit konnte nicht entfernt werden", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unbekannter Speicherfehler.")
        }
    }

    private func favoriteRow(_ favorite: FavoriteFood) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "star.fill")
                .foregroundStyle(.yellow)
                .frame(width: 32, height: 32)
                .background(.yellow.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(favorite.name)
                    .font(.body.weight(.semibold))
                Text(favorite.brand.isEmpty
                    ? "\(favorite.caloriesPer100.formatted(.number.precision(.fractionLength(0)))) kcal / 100 \(favorite.unit)"
                    : favorite.brand
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func removeFavorite(_ favorite: FavoriteFood) {
        modelContext.delete(favorite)

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        FavoritesView(selectedDate: .now, accentColor: .orange)
    }
    .modelContainer(for: [FavoriteFood.self, NutritionEntry.self, CustomFood.self], inMemory: true)
}
