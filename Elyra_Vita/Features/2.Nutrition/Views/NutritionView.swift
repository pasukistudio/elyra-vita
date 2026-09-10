import PasukiUI
import SwiftData
import SwiftUI

// MARK: - NutritionView

/// Tagesansicht für die erste lokale Ernährungserfassung.
struct NutritionView: View {
    // MARK: - Abhängigkeiten

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \NutritionEntry.date, order: .reverse)
    private var entries: [NutritionEntry]

    @Query(sort: \CustomFood.name)
    private var customFoods: [CustomFood]

    @Query(sort: \FavoriteFood.updatedAt, order: .reverse)
    private var favoriteFoods: [FavoriteFood]

    // MARK: - Eingaben

    let selectedDate: Date
    let calorieGoal: Int
    let accentColor: Color

    // MARK: - Zustand

    @State var editingEntry: NutritionEntry?
    @State var deletingEntry: NutritionEntry?
    @State private var favoriteErrorMessage: String?
    @State var isSelectingEntries = false
    @State var selectedEntryIDs = Set<ObjectIdentifier>()
    @State private var showingRecipeEditor = false

    private var dayEntries: [NutritionEntry] {
        entries
            .filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted {
                if $0.mealType.displayOrder != $1.mealType.displayOrder {
                    return $0.mealType.displayOrder < $1.mealType.displayOrder
                }

                // Mehrere Einträge derselben Mahlzeit bleiben zeitlich absteigend.
                return $0.date > $1.date
            }
    }

    private var consumedCalories: Int {
        Int(dayEntries.reduce(0) { $0 + $1.calories }.rounded())
    }

    /// Summiert alle gespeicherten Nährwert-Snapshots des ausgewählten Tages.
    private func total(_ keyPath: KeyPath<NutritionEntry, Double>) -> Double {
        dayEntries.reduce(0) { $0 + $1[keyPath: keyPath] }
    }

    init(
        selectedDate: Date = .now,
        calorieGoal: Int = 1800,
        accentColor: Color
    ) {
        self.selectedDate = selectedDate
        self.calorieGoal = calorieGoal
        self.accentColor = accentColor
    }

    // MARK: - Ansicht

    var body: some View {
        List {
            Section {
                calorieSummary
                    .listRowInsets(EdgeInsets())
            } header: {
                Text("Tagesziel")
            }

            Section {
                NavigationLink {
                    CustomFoodsView(accentColor: accentColor)
                } label: {
                    HStack {
                        Label("Meine Lebensmittel", systemImage: "fork.knife.circle")
                        Spacer()
                        Text(customFoods.count, format: .number)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Meine Lebensmittel")
            }

            if !favoriteFoods.isEmpty {
                Section {
                    NavigationLink {
                        FavoritesView(
                            selectedDate: selectedDate,
                            accentColor: accentColor
                        )
                    } label: {
                        HStack {
                            Label("Meine Favoriten", systemImage: "star.circle")
                            Spacer()
                            Text(favoriteFoods.count, format: .number)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Meine Favoriten")
                }
            }

            Section {
                if dayEntries.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Mahlzeiten",
                        systemImage: "fork.knife.circle",
                        description: Text("Erfasse deine erste Mahlzeit für diesen Tag.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(dayEntries) { entry in
                        entryRow(entry)
                    }
                }
            } header: {
                HStack {
                    Text("Tageslogbuch")
                    Spacer()
                    Button(isSelectingEntries ? "Abbrechen" : "Auswählen") {
                        isSelectingEntries.toggle()
                        if !isSelectingEntries {
                            selectedEntryIDs.removeAll()
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }

            if isSelectingEntries && !selectedEntryIDs.isEmpty {
                Section {
                    Button {
                        showingRecipeEditor = true
                    } label: {
                        Label("Als Rezept speichern", systemImage: "book.badge.plus")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } footer: {
                    Text("Die ausgewählten Lebensmittel und Mengen werden in den Rezepteditor übernommen.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .confirmationDialog(
            "Eintrag löschen?",
            isPresented: Binding(
                get: { deletingEntry != nil },
                set: {
                    if !$0 {
                        deletingEntry = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) { deleteEntry() }
            Button("Abbrechen", role: .cancel) { deletingEntry = nil }
        }
        .alert("Favorit konnte nicht gespeichert werden", isPresented: favoriteErrorPresented) {
            Button("OK", role: .cancel) { favoriteErrorMessage = nil }
        } message: {
            Text(favoriteErrorMessage ?? "Unbekannter Fehler")
        }
        .sheet(item: $editingEntry) { entry in
            AddNutritionEntryView(
                selectedDate: selectedDate,
                accentColor: accentColor,
                entryToEdit: entry
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(.systemBackground))
        }
        .sheet(
            isPresented: $showingRecipeEditor,
            onDismiss: {
                isSelectingEntries = false
                selectedEntryIDs.removeAll()
            },
            content: {
                RecipeEditorView(
                    ingredients: recipeIngredients,
                    defaultTitle: "Meine Mahlzeit",
                    defaultServings: 1,
                    prefilledNutrition: recipeNutrition
                )
            }
        )
    }

    // MARK: - Logbuch

    private var selectedEntries: [NutritionEntry] {
        dayEntries.filter { selectedEntryIDs.contains(ObjectIdentifier($0)) }
    }

    private var recipeIngredients: [RecipeIngredient] {
        selectedEntries.enumerated().map { index, entry in
            RecipeIngredient(
                recipeID: UUID(),
                name: entry.foodName,
                amount: entry.amount.formatted(.number.precision(.fractionLength(0 ... 2))),
                unit: displayUnit(for: entry.unit),
                position: index
            )
        }
    }

    private var recipeNutrition: RecipeNutritionTotals {
        RecipeNutritionTotals(
            calories: selectedEntries.reduce(0) { $0 + $1.calories },
            protein: selectedEntries.reduce(0) { $0 + $1.proteinGrams },
            carbohydrates: selectedEntries.reduce(0) { $0 + $1.carbohydratesGrams },
            fat: selectedEntries.reduce(0) { $0 + $1.fatGrams },
            recognizedIngredients: selectedEntries.count
        )
    }

    // MARK: - Änderungen

    private var favoriteErrorPresented: Binding<Bool> {
        Binding(
            get: { favoriteErrorMessage != nil },
            set: {
                if !$0 {
                    favoriteErrorMessage = nil
                }
            }
        )
    }

    func isFavorite(_ entry: NutritionEntry) -> Bool {
        let food = nutritionFood(for: entry)
        return favoriteFoods.contains { $0.id == food.id }
    }

    func toggleFavorite(_ entry: NutritionEntry) {
        let food = nutritionFood(for: entry)

        if let favorite = favoriteFoods.first(where: { $0.id == food.id }) {
            modelContext.delete(favorite)
        } else {
            modelContext.insert(FavoriteFood(food: food))
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            favoriteErrorMessage = error.localizedDescription
        }
    }

    /// Rekonstruiert die gemeinsame Lebensmittel-Darstellung aus dem Eintrag.
    /// Für bekannte Lebensmittel bleiben vollständige Nährwerte und
    /// Stückangaben erhalten; der Fallback deckt ältere Einträge ab.
    private func nutritionFood(for entry: NutritionEntry) -> NutritionFood {
        if let favorite = favoriteFoods.first(where: { $0.id == entry.externalFoodID }) {
            return favorite.nutritionFood
        }

        if let customFood = customFoods.first(where: { $0.nutritionFood.id == entry.externalFoodID }) {
            return customFood.nutritionFood
        }

        if let localFood = NutritionFood.localCatalog.first(where: { $0.id == entry.externalFoodID }) {
            return localFood
        }

        return NutritionFood.from(entry: entry)
    }

    func displayUnit(for unit: String) -> String {
        unit == "piece" ? "Stück" : unit
    }

    private func deleteEntry() {
        guard let deletingEntry else { return }
        modelContext.delete(deletingEntry)
        if PersistenceErrorReporter.save(modelContext, operation: "Ernährungseintrag löschen") {
            self.deletingEntry = nil
        }
    }
}

private extension NutritionView {
    var calorieSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                    .frame(width: 42, height: 42)
                    .background(.orange.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Kalorien")
                        .font(.subheadline.weight(.semibold))
                    Text("\(consumedCalories) kcal")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.orange)
                }

                Spacer()

                Text("von \(calorieGoal) kcal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            AppProgressBar(
                progress: calorieGoal > 0
                    ? min(Double(consumedCalories) / Double(calorieGoal), 1)
                    : 0,
                color: .orange
            )

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 8
            ) {
                nutrientTile("Eiweiß", total(\.proteinGrams), unit: "g")
                nutrientTile("Kohlenhydrate", total(\.carbohydratesGrams), unit: "g")
                nutrientTile("Fett", total(\.fatGrams), unit: "g")
                nutrientTile("Zucker", total(\.sugarGrams), unit: "g")
                nutrientTile("Ballaststoffe", total(\.fiberGrams), unit: "g")
                nutrientTile("Gesättigte Fettsäuren", total(\.saturatedFatGrams), unit: "g")
                nutrientTile("Salz", total(\.saltGrams), unit: "g")
            }
        }
        .appCard()
    }

    func nutrientTile(_ title: String, _ value: Double, unit: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text("\(value.formatted(.number.precision(.fractionLength(1)))) \(unit)")
                .font(.caption.weight(.semibold))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(title): \(value.formatted(.number.precision(.fractionLength(1)))) \(unit)"
        )
    }
}
