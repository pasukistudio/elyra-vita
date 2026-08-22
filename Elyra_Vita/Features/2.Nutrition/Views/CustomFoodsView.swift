import SwiftUI
import SwiftData

// MARK: - CustomFoodsView

/// Verwaltung der persönlichen Lebensmittel außerhalb des Tageslogbuchs.
struct CustomFoodsView: View {

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CustomFood.name)
    private var customFoods: [CustomFood]

    let accentColor: Color

    @State private var searchText = ""
    @State private var addingFood = false
    @State private var editingFood: CustomFood?
    @State private var deletingFood: CustomFood?
    @State private var errorMessage: String?

    private var filteredFoods: [CustomFood] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return customFoods }

        return customFoods.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
                $0.brand.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        List {
            if filteredFoods.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "Noch keine eigenen Lebensmittel" : "Keine Treffer",
                    systemImage: searchText.isEmpty ? "fork.knife.circle" : "magnifyingglass",
                    description: Text(
                        searchText.isEmpty
                            ? "Lege dein erstes eigenes Lebensmittel an."
                            : "Versuche es mit einem anderen Suchbegriff."
                    )
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(filteredFoods) { food in
                    customFoodRow(food)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Meine Lebensmittel")
        .searchable(text: $searchText, prompt: "Lebensmittel suchen")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    addingFood = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Eigenes Lebensmittel anlegen")
            }
        }
        .confirmationDialog(
            "Eigenes Lebensmittel löschen?",
            isPresented: Binding(
                get: { deletingFood != nil },
                set: { if !$0 { deletingFood = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) { deleteFood() }
            Button("Abbrechen", role: .cancel) { deletingFood = nil }
        } message: {
            Text(deletingFood?.name ?? "")
        }
        .alert(
            "Lebensmittel konnte nicht gelöscht werden",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unbekannter Speicherfehler.")
        }
        .sheet(isPresented: $addingFood) {
            AddCustomFoodView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingFood) { food in
            AddCustomFoodView(foodToEdit: food)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private func customFoodRow(_ food: CustomFood) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "fork.knife.circle.fill")
                .foregroundStyle(accentColor)
                .font(.title3)

            VStack(alignment: .leading, spacing: 3) {
                Text(food.name)
                    .font(.body.weight(.semibold))
                Text(food.brand.isEmpty ? "\(food.caloriesPer100.formatted(.number.precision(.fractionLength(0)))) kcal / 100 \(food.unit)" : food.brand)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Menu {
                Button("Bearbeiten", systemImage: "pencil") {
                    editingFood = food
                }
                Button("Löschen", systemImage: "trash", role: .destructive) {
                    deletingFood = food
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Aktionen für \(food.name)")
        }
        .padding(.vertical, 4)
    }

    private func deleteFood() {
        guard let deletingFood else { return }
        modelContext.delete(deletingFood)

        do {
            try modelContext.save()
            self.deletingFood = nil
        } catch {
            modelContext.rollback()
            self.deletingFood = nil
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        CustomFoodsView(accentColor: .orange)
    }
    .modelContainer(for: [CustomFood.self], inMemory: true)
}
