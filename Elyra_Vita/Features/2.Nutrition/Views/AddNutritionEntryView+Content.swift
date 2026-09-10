import SwiftUI

extension AddNutritionEntryView {
    var formContent: some View {
        Form {
            if selectedFood == nil {
                Section {
                    if savedFoodCount > 0 {
                        Label("\(savedFoodCount) Lebensmittel erfasst", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
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
                    HStack {
                        NutritionFoodRow(
                            food: selectedFood,
                            accentColor: accentColor,
                            isFavorite: isFavorite(selectedFood)
                        )
                        Button("Ändern") { self.selectedFood = nil }
                            .font(.caption.weight(.semibold))
                    }
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
                            NutritionFoodRow(
                                food: food,
                                accentColor: accentColor,
                                isFavorite: isFavorite(food)
                            )
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
                                    Text(option.symbol).tag(option.id)
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
                            Label(mealType.title, systemImage: mealType.icon).tag(mealType)
                        }
                    }
                }

                Section("Nährwerte für diese Menge") {
                    NutritionValueField(title: "Kalorien", text: $caloriesText, unit: "kcal")
                    NutritionValueField(title: "Eiweiß", text: $proteinText, unit: "g")
                    NutritionValueField(title: "Kohlenhydrate", text: $carbohydratesText, unit: "g")
                    NutritionValueField(title: "Fett", text: $fatText, unit: "g")
                    NutritionValueField(title: "Zucker", text: $sugarText, unit: "g")
                    NutritionValueField(title: "Ballaststoffe", text: $fiberText, unit: "g")
                    NutritionValueField(title: "Gesättigte Fettsäuren", text: $saturatedFatText, unit: "g")
                    NutritionValueField(title: "Salz", text: $saltText, unit: "g")
                }

                if entryToEdit == nil {
                    Section {
                        if savedFoodCount > 0 {
                            Text("\(savedFoodCount) Lebensmittel erfasst")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Button("Weiteres Lebensmittel hinzufügen", systemImage: "plus") {
                            save(finishBatch: false)
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                    } footer: {
                        Text(
                            "Das aktuelle Lebensmittel wird gespeichert und du kannst direkt das nächste scannen "
                                + "oder auswählen."
                        )
                    }
                }
            }
        }
    }
}
