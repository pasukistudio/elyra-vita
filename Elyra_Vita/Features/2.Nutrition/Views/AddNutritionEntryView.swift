import Foundation
import PasukiUI
import SwiftData
import SwiftUI

// MARK: - AddNutritionEntryView

/// Erfasst ein lokales Lebensmittel mit frei anpassbarer Menge.
struct AddNutritionEntryView: View {
    // MARK: - Abhängigkeiten

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext

    @Query(sort: \CustomFood.name)
    private var customFoods: [CustomFood]

    @Query(sort: \NutritionEntry.updatedAt, order: .reverse)
    var nutritionEntries: [NutritionEntry]

    @Query(sort: \FavoriteFood.updatedAt, order: .reverse)
    var favoriteFoods: [FavoriteFood]

    // MARK: - Eingaben

    let selectedDate: Date
    let accentColor: Color
    let entryToEdit: NutritionEntry?
    let initialFood: NutritionFood?
    let initialMealType: NutritionMealType

    // MARK: - Zustand

    @State var searchText = ""
    @State var selectedFood: NutritionFood?
    @State var remoteFoods: [NutritionFood] = []
    @State var isLoadingRemoteFoods = false
    @State var scannerPresented = false
    @State var customFoodSheetPresented = false
    @State var errorMessage: String?
    @State var amountText = "100"
    @State var pieceWeightText = ""
    @State var selectedUnit = "g"
    @State var selectedMealType: NutritionMealType = .snack
    @State var caloriesText = ""
    @State var proteinText = ""
    @State var carbohydratesText = ""
    @State var fatText = ""
    @State var sugarText = ""
    @State var fiberText = ""
    @State var saturatedFatText = ""
    @State var saltText = ""
    @State var foodFilter: FoodFilter = .all
    @State var savedFoodCount = 0

    init(
        selectedDate: Date,
        accentColor: Color,
        entryToEdit: NutritionEntry? = nil,
        initialFood: NutritionFood? = nil,
        initialMealType: NutritionMealType = .snack
    ) {
        self.selectedDate = selectedDate
        self.accentColor = accentColor
        self.entryToEdit = entryToEdit
        self.initialFood = initialFood
        self.initialMealType = initialMealType
        _selectedFood = State(initialValue: initialFood)
    }

    // MARK: - Ansicht

    var body: some View {
        NavigationStack {
            formContent
                .navigationTitle(entryToEdit == nil ? "Mahlzeit erfassen" : "Mahlzeit bearbeiten")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") { dismiss() }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button(entryToEdit == nil && savedFoodCount > 0 ? "Fertig" : "Speichern") {
                            if selectedFood == nil && entryToEdit == nil {
                                dismiss()
                            } else {
                                save(finishBatch: true)
                            }
                        }
                        .disabled(!canFinish)
                    }
                }
                .onAppear(perform: prepareForEditing)
                .task(id: "\(searchText)|\(foodFilter.rawValue)") {
                    await searchRemoteFoods()
                }
                .onChange(of: searchText) { _, newValue in
                    if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        foodFilter = .all
                    }
                }
                .onChange(of: scannerPresented) { _, isPresented in
                    if isPresented {
                        // Der Scanner ist ein eigener Flow. Ein eventuell noch
                        // vorhandener Custom-Food-Zustand darf ihn niemals
                        // überlagern.
                        customFoodSheetPresented = false
                    }
                }
                .onChange(of: amountText) { _, newValue in
                    guard let selectedFood,
                          let amount = NutritionNumberParser.parse(newValue),
                          amount > 0 else { return }
                    setNutritionFields(for: selectedFood, amount: amount, unit: selectedUnit)
                }
                .onChange(of: selectedUnit) { _, newUnit in
                    guard let selectedFood else { return }
                    if entryToEdit == nil {
                        amountText = newUnit == NutritionUnitFormatter.baseUnit(for: selectedFood.unit) ? "100" : "1"
                    }
                    guard let amount = NutritionNumberParser.parse(amountText) else { return }
                    setNutritionFields(for: selectedFood, amount: amount, unit: newUnit)
                }
                .onChange(of: pieceWeightText) { _, _ in
                    if !selectedUnitOptions.contains(where: { $0.id == selectedUnit }) {
                        selectedUnit = selectedFood?.unit ?? "g"
                    }
                    guard let selectedFood,
                          let amount = parsedAmount,
                          amount > 0 else { return }
                    setNutritionFields(for: selectedFood, amount: amount, unit: selectedUnit)
                }
                .fullScreenCover(isPresented: $scannerPresented) {
                    BarcodeScannerView(
                        onBarcode: { barcode in
                            scannerPresented = false
                            Task { @MainActor in
                                // Erst den Scanner vollständig schließen, danach
                                // Produkt übernehmen oder bei keinem Treffer das
                                // eigene Lebensmittel gezielt öffnen.
                                try? await Task.sleep(for: .milliseconds(350))
                                await loadBarcode(barcode)
                            }
                        },
                        onUnavailable: {
                            scannerPresented = false
                            errorMessage = "Der Barcode-Scanner ist auf diesem Gerät nicht verfügbar."
                        }
                    )
                    .ignoresSafeArea()
                }
                .sheet(isPresented: $customFoodSheetPresented) {
                    AddCustomFoodView { food in
                        selectFood(food)
                        customFoodSheetPresented = false
                    }
                    .presentationDetents([.large])
                    .presentationBackground(Color(.systemBackground))
                    .presentationDragIndicator(.visible)
                }
                .alert("Lebensmittel nicht gefunden", isPresented: Binding(
                    get: { errorMessage != nil },
                    set: {
                        if !$0 {
                            errorMessage = nil
                        }
                    }
                )) {
                    Button("OK", role: .cancel) { errorMessage = nil }
                } message: {
                    Text(errorMessage ?? "")
                }
        }
    }
}

extension AddNutritionEntryView {
    var filteredFoods: [NutritionFood] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let localFoods: [NutritionFood]

        switch foodFilter {
        case .all:
            localFoods = customFoods.map(\.nutritionFood) + NutritionFood.localCatalog
        case .favorites:
            localFoods = favoriteFoodsForDisplay
        case .recent:
            localFoods = recentlyUsedFoods
        }

        guard !query.isEmpty else { return localFoods }

        let matchingLocalFoods = localFoods.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }

        guard foodFilter == .all else { return matchingLocalFoods }

        return matchingLocalFoods + remoteFoods.filter { remote in
            !matchingLocalFoods.contains(where: { $0.id == remote.id })
        }
    }

    private var favoriteFoodsForDisplay: [NutritionFood] {
        Array(favoriteFoods.map(\.nutritionFood).prefix(5))
    }

    /// Liefert die zuletzt geloggten Lebensmittel aus allen Quellen.
    /// Dazu gehören auch gescannte Open-Food-Facts-Produkte.
    private var recentlyUsedFoods: [NutritionFood] {
        var seenIDs = Set<String>()
        let foods: [NutritionFood] = nutritionEntries.compactMap { entry in
            let key = entry.externalFoodID.isEmpty
                ? "\(entry.source)-\(entry.foodName)"
                : entry.externalFoodID

            guard seenIDs.insert(key).inserted else { return nil }
            return nutritionFood(for: entry)
        }

        return Array(foods.prefix(12))
    }

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

    var parsedAmount: Double? {
        NutritionNumberParser.parse(amountText)
    }

    private var canSaveCurrentFood: Bool {
        selectedFood != nil
            && (parsedAmount ?? 0) > 0
            && nutritionValues != nil
            && (selectedUnit != "piece" || pieceWeight != nil)
    }

    private var canFinish: Bool {
        if entryToEdit != nil {
            return canSaveCurrentFood
        }
        return selectedFood == nil ? savedFoodCount > 0 : canSaveCurrentFood
    }

    var pieceWeight: Double? {
        guard let value = NutritionNumberParser.parse(pieceWeightText), value > 0 else { return nil }
        return value
    }

    var selectedUnitOptions: [NutritionUnitOption] {
        guard let selectedFood else { return [] }
        let baseUnit = NutritionUnitFormatter.baseUnit(for: selectedFood.unit)
        var options = [NutritionUnitOption(
            id: baseUnit,
            title: NutritionUnitFormatter.title(for: baseUnit),
            symbol: NutritionUnitFormatter.symbol(for: baseUnit),
            baseAmount: 1
        )]

        options.append(NutritionUnitOption(
            id: "piece",
            title: "Stück",
            symbol: "Stück",
            baseAmount: pieceWeight ?? 1
        ))

        return options
    }

    var baseAmountDescription: String? {
        guard let selectedFood,
              selectedUnit != selectedFood.unit,
              let amount = parsedAmount,
              amount > 0 else { return nil }

        let baseAmount = selectedUnitOptions
            .first(where: { $0.id == selectedUnit })
            .map { amount * $0.baseAmount }
            ?? selectedFood.baseAmount(for: amount, unit: selectedUnit)
        let formattedAmount = baseAmount.rounded() == baseAmount
            ? String(Int(baseAmount))
            : NutritionNumberParser.format(baseAmount)

        return "entspricht ca. \(formattedAmount) \(selectedFood.unit)"
    }

    var nutritionValues: [Double]? {
        let values = [caloriesText, proteinText, carbohydratesText, fatText,
                      sugarText, fiberText, saturatedFatText, saltText]
            .map(NutritionNumberParser.parse)

        guard values.allSatisfy({ $0.map { $0 >= 0 } ?? false }) else { return nil }
        return values.compactMap { $0 }
    }

    func selectFood(_ food: NutritionFood) {
        let recentEntry = recentlyUsedEntry(for: food)
        let savedPieceWeight = recentEntry.flatMap { $0.pieceWeight > 0 ? $0.pieceWeight : nil }
            ?? favoriteFoods.first(where: { $0.id == food.id })?.pieceWeight
            ?? nutritionEntries.first(where: { $0.externalFoodID == food.id && $0.pieceWeight > 0 })?.pieceWeight
        selectedFood = food
        pieceWeightText = savedPieceWeight.map(NutritionNumberParser.format)
            ?? food.pieceWeight.map(NutritionNumberParser.format)
            ?? ""
        searchText = ""
        amountText = recentEntry.map { NutritionNumberParser.format($0.amount) } ?? "100"
        let rememberedUnit = recentEntry?.unit ?? NutritionUnitFormatter.baseUnit(for: food.unit)
        selectedUnit = selectedUnitOptions.contains(where: { $0.id == rememberedUnit })
            ? rememberedUnit
            : NutritionUnitFormatter.baseUnit(for: food.unit)
        let amount = parsedAmount ?? 100
        setNutritionFields(for: food, amount: amount, unit: selectedUnit)
    }

    private func setNutritionFields(for food: NutritionFood, amount: Double, unit: String) {
        let factor = selectedUnitOptions
            .first(where: { $0.id == unit })
            .map { amount * $0.baseAmount / 100 }
            ?? food.baseAmount(for: amount, unit: unit) / 100
        caloriesText = NutritionNumberParser.format(food.caloriesPer100 * factor)
        proteinText = NutritionNumberParser.format(food.proteinPer100 * factor)
        carbohydratesText = NutritionNumberParser.format(food.carbohydratesPer100 * factor)
        fatText = NutritionNumberParser.format(food.fatPer100 * factor)
        sugarText = NutritionNumberParser.format(food.sugarPer100 * factor)
        fiberText = NutritionNumberParser.format(food.fiberPer100 * factor)
        saturatedFatText = NutritionNumberParser.format(food.saturatedFatPer100 * factor)
        saltText = NutritionNumberParser.format(food.saltPer100 * factor)
    }

    private func setNutritionFields(from entry: NutritionEntry) {
        caloriesText = NutritionNumberParser.format(entry.calories)
        proteinText = NutritionNumberParser.format(entry.proteinGrams)
        carbohydratesText = NutritionNumberParser.format(entry.carbohydratesGrams)
        fatText = NutritionNumberParser.format(entry.fatGrams)
        sugarText = NutritionNumberParser.format(entry.sugarGrams)
        fiberText = NutritionNumberParser.format(entry.fiberGrams)
        saturatedFatText = NutritionNumberParser.format(entry.saturatedFatGrams)
        saltText = NutritionNumberParser.format(entry.saltGrams)
    }

    private func prepareForEditing() {
        if let entryToEdit {
            selectedMealType = entryToEdit.mealType
            amountText = NutritionNumberParser.format(entryToEdit.amount)
            selectedFood = NutritionFood.localCatalog.first { $0.id == entryToEdit.externalFoodID }
                ?? NutritionFood.localCatalog.first { $0.name == entryToEdit.foodName }
                ?? customFoods.map(\.nutritionFood).first { $0.id == entryToEdit.externalFoodID }
                ?? customFoods.map(\.nutritionFood).first { $0.name == entryToEdit.foodName }
                ?? nutritionFood(for: entryToEdit)
            selectedUnit = entryToEdit.unit
            pieceWeightText = entryToEdit.pieceWeight > 0
                ? NutritionNumberParser.format(entryToEdit.pieceWeight)
                : ""
            if let selectedFood, !selectedUnitOptions.contains(where: { $0.id == selectedUnit }) {
                selectedUnit = selectedFood.unit
            }
            setNutritionFields(from: entryToEdit)
        } else {
            selectedMealType = initialMealType
            if let initialFood {
                pieceWeightText = initialFood.pieceWeight.map(NutritionNumberParser.format) ?? ""
                selectedUnit = NutritionUnitFormatter.baseUnit(for: initialFood.unit)
                amountText = "100"
                setNutritionFields(for: initialFood, amount: 100, unit: selectedUnit)
            }
        }
    }
}
