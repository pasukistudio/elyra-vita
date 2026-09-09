import SwiftUI
import SwiftData

// MARK: - FavoriteQuickAddView

/// Kompakte Mengenerfassung für ein favorisiertes Lebensmittel.
struct FavoriteQuickAddView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var favoriteFoods: [FavoriteFood]

    let selectedDate: Date
    let accentColor: Color
    let food: NutritionFood

    @State private var amountText = "100"
    @State private var pieceWeightText: String
    @State private var selectedUnit: String
    @State private var selectedMealType: NutritionMealType = .snack
    @State private var errorMessage: String?

    init(selectedDate: Date, accentColor: Color, food: NutritionFood) {
        self.selectedDate = selectedDate
        self.accentColor = accentColor
        self.food = food
        _pieceWeightText = State(
            initialValue: food.pieceWeight.map {
                $0.formatted(.number.precision(.fractionLength(0...2)))
            } ?? ""
        )
        _selectedUnit = State(initialValue: food.unit == "piece" ? "g" : food.unit)
    }

    private var amount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "."))
    }

    private var pieceWeight: Double? {
        guard let value = Double(pieceWeightText.replacingOccurrences(of: ",", with: ".")),
              value > 0,
              value.isFinite else {
            return nil
        }
        return value
    }

    /// NutritionFood stores values per 100 g/ml. Older favorites may still
    /// contain `piece` as their base unit, which is normalized for input.
    private var baseUnit: String {
        food.unit == "piece" ? "g" : food.unit
    }

    private var unitOptions: [NutritionUnitOption] {
        var options = [NutritionUnitOption(
            id: baseUnit,
            title: displayUnitTitle(for: baseUnit),
            symbol: displayUnitSymbol(for: baseUnit),
            baseAmount: 1
        )]

        if let pieceWeight, pieceWeight > 0 {
            options.append(NutritionUnitOption(
                id: "piece",
                title: "Stück",
                symbol: "Stück",
                baseAmount: pieceWeight
            ))
        }

        return options
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .frame(width: 36, height: 36)
                            .background(.yellow.opacity(0.14), in: Circle())

                        VStack(alignment: .leading, spacing: 3) {
                            Text(food.name)
                                .font(.headline)
                            if !food.brand.isEmpty {
                                Text(food.brand)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Menge") {
                    HStack {
                        TextField("Menge", text: $amountText)
                            .keyboardType(.decimalPad)

                        if unitOptions.count > 1 {
                            Picker("Einheit", selection: $selectedUnit) {
                                ForEach(unitOptions) { option in
                                    Text(option.symbol).tag(option.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }
                    }

                    if selectedUnit == "piece" {
                        HStack {
                            Text("Gramm pro Stück")
                            Spacer()
                            TextField("z. B. 50", text: $pieceWeightText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                            Text("g")
                                .foregroundStyle(.secondary)
                        }
                        Text("1 Stück entspricht dieser Grammzahl.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 8
                    ) {
                        quickAmountButton(100, unit: baseUnit)
                        quickAmountButton(200, unit: baseUnit)

                        if pieceWeight != nil {
                            quickAmountButton(1, unit: "piece", title: "1 Stück")
                        }

                        Button("Eigene Menge") {
                            amountText = ""
                            selectedUnit = baseUnit
                        }
                        .buttonStyle(.bordered)
                        .tint(accentColor)
                    }
                }

                Section("Mahlzeit") {
                    Picker("Mahlzeit", selection: $selectedMealType) {
                        ForEach(NutritionMealType.allCases) { mealType in
                            Label(mealType.title, systemImage: mealType.icon)
                                .tag(mealType)
                        }
                    }
                }
            }
            .navigationTitle("Schnell hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: pieceWeightText) { _, _ in
                if !unitOptions.contains(where: { $0.id == selectedUnit }) {
                    selectedUnit = baseUnit
                }
            }
            .onChange(of: selectedUnit) { _, newUnit in
                amountText = newUnit == baseUnit ? "100" : "1"
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") { save() }
                        .disabled((amount ?? 0) <= 0 || (selectedUnit == "piece" && pieceWeight == nil))
                }
            }
            .alert("Lebensmittel konnte nicht gespeichert werden", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Unbekannter Speicherfehler.")
            }
        }
    }

    private func quickAmountButton(
        _ value: Double,
        unit: String,
        title: String? = nil
    ) -> some View {
        Button(title ?? "\(value.formatted(.number.precision(.fractionLength(0)))) \(displayUnit(for: unit))") {
            amountText = value.formatted(.number.precision(.fractionLength(0)))
            selectedUnit = unit
        }
        .buttonStyle(.bordered)
        .tint(accentColor)
    }

    private func displayUnit(for unit: String) -> String {
        unitOptions.first(where: { $0.id == unit })?.symbol ?? displayUnitSymbol(for: unit)
    }

    private func displayUnitTitle(for unit: String) -> String {
        switch unit {
        case "piece": return "Stück"
        case "ml": return "Milliliter"
        default: return "Gramm"
        }
    }

    private func displayUnitSymbol(for unit: String) -> String {
        switch unit {
        case "piece": return "Stück"
        case "ml": return "ml"
        default: return "g"
        }
    }

    private func save() {
        guard let amount, amount > 0 else { return }

        let factor: Double
        if let unitOption = unitOptions.first(where: { $0.id == selectedUnit }) {
            factor = amount * unitOption.baseAmount / 100
        } else {
            factor = food.baseAmount(for: amount, unit: selectedUnit) / 100
        }

        if let pieceWeight,
           let favorite = favoriteFoods.first(where: { $0.id == food.id }) {
            favorite.pieceWeight = pieceWeight
            favorite.updatedAt = .now
        }
        modelContext.insert(NutritionEntry(
            foodName: food.name,
            brand: food.brand,
            mealType: selectedMealType,
            amount: amount,
            unit: selectedUnit,
            pieceWeight: pieceWeight ?? 0,
            calories: food.caloriesPer100 * factor,
            proteinGrams: food.proteinPer100 * factor,
            carbohydratesGrams: food.carbohydratesPer100 * factor,
            fatGrams: food.fatPer100 * factor,
            sugarGrams: food.sugarPer100 * factor,
            fiberGrams: food.fiberPer100 * factor,
            saturatedFatGrams: food.saturatedFatPer100 * factor,
            saltGrams: food.saltPer100 * factor,
            date: selectedDate,
            source: food.source,
            externalFoodID: food.id
        ))

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    FavoriteQuickAddView(
        selectedDate: .now,
        accentColor: .orange,
        food: NutritionFood.localCatalog[0]
    )
    .modelContainer(for: [NutritionEntry.self, FavoriteFood.self, CustomFood.self], inMemory: true)
}
