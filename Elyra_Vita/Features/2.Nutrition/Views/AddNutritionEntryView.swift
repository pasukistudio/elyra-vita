import SwiftUI
import SwiftData
import PasukiUI
import Foundation

// MARK: - AddNutritionEntryView

/// Erfasst ein lokales Lebensmittel mit frei anpassbarer Menge.
struct AddNutritionEntryView: View {

    // MARK: - Abhängigkeiten

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CustomFood.name)
    private var customFoods: [CustomFood]

    @Query(sort: \NutritionEntry.date, order: .reverse)
    private var nutritionEntries: [NutritionEntry]

    @Query(sort: \FavoriteFood.updatedAt, order: .reverse)
    private var favoriteFoods: [FavoriteFood]

    // MARK: - Eingaben

    let selectedDate: Date
    let accentColor: Color
    let entryToEdit: NutritionEntry?
    let initialFood: NutritionFood?
    let initialMealType: NutritionMealType

    // MARK: - Zustand

    @State private var searchText = ""
    @State private var selectedFood: NutritionFood?
    @State private var remoteFoods: [NutritionFood] = []
    @State private var isLoadingRemoteFoods = false
    @State private var scannerPresented = false
    @State private var errorMessage: String?
    @State private var amountText = "100"
    @State private var pieceWeightText = ""
    @State private var selectedUnit = "g"
    @State private var selectedMealType: NutritionMealType = .snack
    @State private var caloriesText = ""
    @State private var proteinText = ""
    @State private var carbohydratesText = ""
    @State private var fatText = ""
    @State private var sugarText = ""
    @State private var fiberText = ""
    @State private var saturatedFatText = ""
    @State private var saltText = ""
    @State private var customFoodSheetPresented = false
    @State private var foodFilter: FoodFilter = .all

    private var filteredFoods: [NutritionFood] {
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

            guard seenIDs.insert(key).inserted else {
                return nil
            }

            return nutritionFood(for: entry)
        }

        return Array(foods.prefix(5))
    }

    /// Rekonstruiert ein Lebensmittel aus einem gespeicherten Verzehr.
    /// Bekannte lokale und eigene Lebensmittel liefern den vollständigen
    /// Katalogeintrag; externe Produkte bleiben dank des Snapshots ebenfalls
    /// erneut auswählbar.
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

        let isPieceEntry = entry.unit == "piece" && entry.pieceWeight > 0
        let amountFactor: Double
        if isPieceEntry {
            amountFactor = entry.pieceWeight / 100
        } else if entry.unit == "g" || entry.unit == "ml" {
            amountFactor = max(entry.amount, 1) / 100
        } else {
            amountFactor = 1
        }

        return NutritionFood(
            id: entry.externalFoodID.isEmpty
                ? "recent-\(entry.source)-\(entry.foodName)"
                : entry.externalFoodID,
            name: entry.foodName,
            brand: entry.brand,
            unit: isPieceEntry ? "g" : entry.unit,
            caloriesPer100: entry.calories / amountFactor,
            proteinPer100: entry.proteinGrams / amountFactor,
            carbohydratesPer100: entry.carbohydratesGrams / amountFactor,
            fatPer100: entry.fatGrams / amountFactor,
            sugarPer100: entry.sugarGrams / amountFactor,
            fiberPer100: entry.fiberGrams / amountFactor,
            saturatedFatPer100: entry.saturatedFatGrams / amountFactor,
            saltPer100: entry.saltGrams / amountFactor,
            source: entry.source
        )
    }

    private var parsedAmount: Double? {
        parsedNumber(amountText)
    }

    private var pieceWeight: Double? {
        guard let value = parsedNumber(pieceWeightText), value > 0 else { return nil }
        return value
    }

    private var selectedUnitOptions: [NutritionUnitOption] {
        guard let selectedFood else { return [] }
        var options = [NutritionUnitOption(
            id: selectedFood.unit,
            title: selectedFood.unit == "ml" ? "Milliliter" : "Gramm",
            symbol: selectedFood.unit,
            baseAmount: 1
        )]

        options.append(NutritionUnitOption(
            id: "piece",
            title: "Stück",
            symbol: "Stück",
            baseAmount: pieceWeight ?? 0
        ))

        return options
    }

    // MARK: - Mengenanzeige

    /// Zeigt bei alternativen Einheiten die zugrunde liegende Gramm-/Milliliter-Menge.
    /// So bleibt nachvollziehbar, welcher Datenbankwert für ein Stück verwendet wird.
    private var baseAmountDescription: String? {
        guard let selectedFood,
              selectedUnit != selectedFood.unit,
              let amount = parsedAmount,
              amount > 0 else { return nil }

        let baseAmount: Double
        if let option = selectedUnitOptions.first(where: { $0.id == selectedUnit }) {
            baseAmount = amount * option.baseAmount
        } else {
            baseAmount = selectedFood.baseAmount(for: amount, unit: selectedUnit)
        }
        let formattedAmount = baseAmount.rounded() == baseAmount
            ? String(Int(baseAmount))
            : editableNumber(baseAmount)

        return "entspricht ca. \(formattedAmount) \(selectedFood.unit)"
    }

    private var nutritionValues: [Double]? {
        let values = [
            parsedNumber(caloriesText),
            parsedNumber(proteinText),
            parsedNumber(carbohydratesText),
            parsedNumber(fatText),
            parsedNumber(sugarText),
            parsedNumber(fiberText),
            parsedNumber(saturatedFatText),
            parsedNumber(saltText)
        ]

        guard values.allSatisfy({ $0 != nil && $0! >= 0 }) else { return nil }
        return values.compactMap { $0 }
    }

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
            Form {
                if selectedFood == nil {
                    Section {
                        VStack(spacing: 12) {
                            Picker("Lebensmittel anzeigen", selection: $foodFilter) {
                                ForEach(FoodFilter.allCases) { filter in
                                    Text(filter.title).tag(filter)
                                }
                            }
                            .pickerStyle(.segmented)
                            .accessibilityLabel("Lebensmittelfilter")

                            Divider()

                            HStack {
                                TextField("Suchen", text: $searchText)
                                    .textInputAutocapitalization(.never)

                                Button {
                                    scannerPresented = true
                                } label: {
                                    Image(systemName: "barcode.viewfinder")
                                        .font(.title3)
                                        .foregroundStyle(accentColor)
                                }
                                .accessibilityLabel("Barcode scannen")
                            }

                            Divider()

                            Button {
                                customFoodSheetPresented = true
                            } label: {
                                Label("Eigenes Lebensmittel anlegen", systemImage: "plus.circle")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Lebensmittel") {

                    if let selectedFood {
                        selectedFoodRow(selectedFood)
                    } else {
                        if isLoadingRemoteFoods {
                            HStack(spacing: 8) {
                                SwiftUI.ProgressView()
                                Text("Open Food Facts wird durchsucht …")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        ForEach(filteredFoods) { food in
                            Button {
                                selectFood(food)
                            } label: {
                                foodRow(food)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(
                                    isFavorite(food)
                                        ? "Aus Favoriten entfernen"
                                        : "Als Favorit markieren",
                                    systemImage: isFavorite(food) ? "star.slash" : "star"
                                ) {
                                    toggleFavorite(food)
                                }
                            }
                        }
                    }
                }

                if selectedFood != nil {
                    Section("Menge") {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                TextField("Menge", text: $amountText)
                                    .keyboardType(.decimalPad)

                                Picker("Einheit", selection: $selectedUnit) {
                                    ForEach(selectedUnitOptions) { option in
                                        Text(option.symbol)
                                            .tag(option.id)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
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

                            if let baseAmountDescription {
                                Text(baseAmountDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Picker("Mahlzeit", selection: $selectedMealType) {
                            ForEach(NutritionMealType.allCases) { mealType in
                                Label(mealType.title, systemImage: mealType.icon)
                                .tag(mealType)
                            }
                        }
                    }

                    Section("Nährwerte für diese Menge") {
                        nutrientField("Kalorien", text: $caloriesText, unit: "kcal")
                        nutrientField("Eiweiß", text: $proteinText, unit: "g")
                        nutrientField("Kohlenhydrate", text: $carbohydratesText, unit: "g")
                        nutrientField("Fett", text: $fatText, unit: "g")
                        nutrientField("Zucker", text: $sugarText, unit: "g")
                        nutrientField("Ballaststoffe", text: $fiberText, unit: "g")
                        nutrientField("Gesättigte Fettsäuren", text: $saturatedFatText, unit: "g")
                        nutrientField("Salz", text: $saltText, unit: "g")
                    }
                }
            }
            .navigationTitle(entryToEdit == nil ? "Mahlzeit erfassen" : "Mahlzeit bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { save() }
                        .disabled(
                            selectedFood == nil
                                || (parsedAmount ?? 0) <= 0
                                || nutritionValues == nil
                                || (selectedUnit == "piece" && pieceWeight == nil)
                        )
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
            .onChange(of: amountText) { _, newValue in
                guard entryToEdit == nil,
                      let selectedFood,
                      let amount = parsedNumber(newValue),
                      amount > 0 else { return }
                setNutritionFields(for: selectedFood, amount: amount, unit: selectedUnit)
            }
            .onChange(of: selectedUnit) { _, newUnit in
                guard let selectedFood else { return }
                amountText = newUnit == selectedFood.unit ? "100" : "1"
                guard let amount = parsedNumber(amountText) else { return }
                if entryToEdit == nil {
                    setNutritionFields(for: selectedFood, amount: amount, unit: newUnit)
                }
            }
            .onChange(of: pieceWeightText) { _, _ in
                if !selectedUnitOptions.contains(where: { $0.id == selectedUnit }) {
                    selectedUnit = selectedFood?.unit ?? "g"
                }
                guard entryToEdit == nil,
                      let selectedFood,
                      let amount = parsedAmount,
                      amount > 0 else { return }
                setNutritionFields(for: selectedFood, amount: amount, unit: selectedUnit)
            }
            .sheet(isPresented: $scannerPresented) {
                BarcodeScannerView(
                    onBarcode: { barcode in
                        scannerPresented = false
                        Task { await loadBarcode(barcode) }
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
                }
                .presentationDetents([.large])
                .presentationBackground(Color(.systemBackground))
                .presentationDragIndicator(.visible)
            }
            .alert("Lebensmittel nicht gefunden", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Lebensmittelzeilen

    private func foodRow(_ food: NutritionFood) -> some View {
        HStack {
            Image(systemName: "fork.knife")
                .foregroundStyle(accentColor)
                .frame(width: 28)

            Text(food.name)
                .foregroundStyle(.primary)

            Spacer()

            if isFavorite(food) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("Favorit")
            }

            Text(food.caloriesPer100, format: .number.precision(.fractionLength(0)))
                .foregroundStyle(.secondary)
            Text("kcal/100")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func selectedFoodRow(_ food: NutritionFood) -> some View {
        HStack {
            foodRow(food)
            Button("Ändern") {
                selectedFood = nil
            }
            .font(.caption.weight(.semibold))
        }
    }

    private func selectFood(_ food: NutritionFood) {
        let savedPieceWeight = favoriteFoods.first(where: { $0.id == food.id })?.pieceWeight
            ?? nutritionEntries.first(where: { $0.externalFoodID == food.id && $0.pieceWeight > 0 })?.pieceWeight
        selectedFood = food
        pieceWeightText = savedPieceWeight.map(editableNumber) ?? food.pieceWeight.map(editableNumber) ?? ""
        searchText = ""
        amountText = "100"
        selectedUnit = food.unit
        setNutritionFields(for: food, amount: 100, unit: food.unit)
    }

    private func isFavorite(_ food: NutritionFood) -> Bool {
        favoriteFoods.contains { $0.id == food.id }
    }

    private func toggleFavorite(_ food: NutritionFood) {
        if let favorite = favoriteFoods.first(where: { $0.id == food.id }) {
            modelContext.delete(favorite)
        } else {
            modelContext.insert(FavoriteFood(food: food))
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func nutrientField(_ title: String, text: Binding<String>, unit: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)

            Spacer()

            TextField("", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 72)
                .accessibilityLabel(title)

            Text(unit)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Speichern

    private func parsedNumber(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }

    // MARK: - Open Food Facts

    /// Sucht erst nach einer kurzen Eingabepause, damit nicht jeder Tastendruck
    /// eine Netzwerkanfrage auslöst. Der lokale Katalog bleibt sofort sichtbar.
    private func searchRemoteFoods() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2, selectedFood == nil, foodFilter == .all else {
            remoteFoods = []
            return
        }

        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }

        isLoadingRemoteFoods = true
        defer { isLoadingRemoteFoods = false }

        do {
            remoteFoods = try await OpenFoodFactsService().search(query)
        } catch {
            // Eine nicht erreichbare Datenbank darf die lokale Erfassung nicht blockieren.
            remoteFoods = []
        }
    }

    /// Lädt ein konkretes Produkt nach einem Barcode-Scan.
    private func loadBarcode(_ barcode: String) async {
        do {
            guard let food = try await OpenFoodFactsService().product(for: barcode) else {
                errorMessage = "Für diesen Barcode wurden keine verwertbaren Nährwerte gefunden."
                return
            }

            selectFood(food)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func editableNumber(_ value: Double) -> String {
        String(format: "%.2f", value).replacingOccurrences(of: ".", with: ",")
    }

    /// Überträgt die Datenbankwerte auf die aktuell eingegebene Menge.
    private func setNutritionFields(for food: NutritionFood, amount: Double, unit: String) {
        let factor: Double
        if let option = selectedUnitOptions.first(where: { $0.id == unit }) {
            factor = amount * option.baseAmount / 100
        } else {
            factor = food.baseAmount(for: amount, unit: unit) / 100
        }
        caloriesText = editableNumber(food.caloriesPer100 * factor)
        proteinText = editableNumber(food.proteinPer100 * factor)
        carbohydratesText = editableNumber(food.carbohydratesPer100 * factor)
        fatText = editableNumber(food.fatPer100 * factor)
        sugarText = editableNumber(food.sugarPer100 * factor)
        fiberText = editableNumber(food.fiberPer100 * factor)
        saturatedFatText = editableNumber(food.saturatedFatPer100 * factor)
        saltText = editableNumber(food.saltPer100 * factor)
    }

    /// Lädt beim Bearbeiten die bereits gespeicherten, ggf. korrigierten Werte.
    private func setNutritionFields(from entry: NutritionEntry) {
        caloriesText = editableNumber(entry.calories)
        proteinText = editableNumber(entry.proteinGrams)
        carbohydratesText = editableNumber(entry.carbohydratesGrams)
        fatText = editableNumber(entry.fatGrams)
        sugarText = editableNumber(entry.sugarGrams)
        fiberText = editableNumber(entry.fiberGrams)
        saturatedFatText = editableNumber(entry.saturatedFatGrams)
        saltText = editableNumber(entry.saltGrams)
    }

    private func prepareForEditing() {
        if let entryToEdit {
            selectedMealType = entryToEdit.mealType
            amountText = editableNumber(entryToEdit.amount)
            selectedFood = NutritionFood.localCatalog.first {
                $0.id == entryToEdit.externalFoodID
            } ?? NutritionFood.localCatalog.first {
                $0.name == entryToEdit.foodName
            } ?? customFoods.map(\.nutritionFood).first {
                $0.id == entryToEdit.externalFoodID
            } ?? customFoods.map(\.nutritionFood).first {
                $0.name == entryToEdit.foodName
            }
            selectedUnit = entryToEdit.unit
            pieceWeightText = entryToEdit.pieceWeight > 0 ? editableNumber(entryToEdit.pieceWeight) : ""
            if let selectedFood,
               !selectedUnitOptions.contains(where: { $0.id == selectedUnit }) {
                selectedUnit = selectedFood.unit
            }
            setNutritionFields(from: entryToEdit)
        } else {
            selectedMealType = initialMealType
            if let initialFood {
                pieceWeightText = initialFood.pieceWeight.map(editableNumber) ?? ""
                selectedUnit = initialFood.unit
                setNutritionFields(for: initialFood, amount: 100, unit: initialFood.unit)
            }
        }
    }

    private func save() {
        guard let selectedFood,
              let amount = parsedAmount,
              amount > 0,
              let values = nutritionValues,
              values.count == 8 else { return }

        let calories = values[0]
        let protein = values[1]
        let carbohydrates = values[2]
        let fat = values[3]
        let sugar = values[4]
        let fiber = values[5]
        let saturatedFat = values[6]
        let salt = values[7]

        if let entryToEdit {
            entryToEdit.foodName = selectedFood.name
            entryToEdit.brand = selectedFood.brand
            entryToEdit.unit = selectedUnit
            entryToEdit.pieceWeight = pieceWeight ?? 0
            entryToEdit.externalFoodID = selectedFood.id
            entryToEdit.source = selectedFood.source
            entryToEdit.update(
                mealType: selectedMealType,
                amount: amount,
                date: entryToEdit.date
            )
            entryToEdit.calories = calories
            entryToEdit.proteinGrams = protein
            entryToEdit.carbohydratesGrams = carbohydrates
            entryToEdit.fatGrams = fat
            entryToEdit.sugarGrams = sugar
            entryToEdit.fiberGrams = fiber
            entryToEdit.saturatedFatGrams = saturatedFat
            entryToEdit.saltGrams = salt
            entryToEdit.updatedAt = .now
        } else {
            modelContext.insert(
                NutritionEntry(
                    foodName: selectedFood.name,
                    brand: selectedFood.brand,
                    mealType: selectedMealType,
                    amount: amount,
                    unit: selectedUnit,
                    pieceWeight: pieceWeight ?? 0,
                    calories: calories,
                    proteinGrams: protein,
                    carbohydratesGrams: carbohydrates,
                    fatGrams: fat,
                    sugarGrams: sugar,
                    fiberGrams: fiber,
                    saturatedFatGrams: saturatedFat,
                    saltGrams: salt,
                    date: selectedDate,
                    source: selectedFood.source,
                    externalFoodID: selectedFood.id
                )
            )
        }

        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    AddNutritionEntryView(selectedDate: .now, accentColor: .orange)
        .modelContainer(for: [NutritionEntry.self, CustomFood.self, FavoriteFood.self], inMemory: true)
}

private enum FoodFilter: String, CaseIterable, Identifiable {
    case all
    case favorites
    case recent

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "Alle"
        case .favorites: "Favoriten"
        case .recent: "Zuletzt"
        }
    }
}
