import SwiftUI
import SwiftData

// MARK: - AddCustomFoodView

/// Erfasst ein persönliches Lebensmittel inklusive vollständiger Nährwerte.
struct AddCustomFoodView: View {

    // MARK: - Abhängigkeiten

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // MARK: - Eingaben

    let foodToEdit: CustomFood?
    let onSaved: (NutritionFood) -> Void

    // MARK: - Zustand

    @State private var name = ""
    @State private var brand = ""
    @State private var unit = "g"
    @State private var pieceWeight = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbohydrates = ""
    @State private var fat = ""
    @State private var sugar = ""
    @State private var fiber = ""
    @State private var saturatedFat = ""
    @State private var salt = ""
    @State private var saveErrorMessage: String?

    init(
        foodToEdit: CustomFood? = nil,
        onSaved: @escaping (NutritionFood) -> Void = { _ in }
    ) {
        self.foodToEdit = foodToEdit
        self.onSaved = onSaved
        _name = State(initialValue: foodToEdit?.name ?? "")
        _brand = State(initialValue: foodToEdit?.brand ?? "")
        _unit = State(initialValue: foodToEdit?.unit ?? "g")
        _pieceWeight = State(
            initialValue: foodToEdit.map { $0.pieceWeight > 0 ? Self.editableNumber($0.pieceWeight) : "" } ?? ""
        )
        _calories = State(initialValue: foodToEdit.map { Self.editableNumber($0.caloriesPer100) } ?? "")
        _protein = State(initialValue: foodToEdit.map { Self.editableNumber($0.proteinPer100) } ?? "")
        _carbohydrates = State(initialValue: foodToEdit.map { Self.editableNumber($0.carbohydratesPer100) } ?? "")
        _fat = State(initialValue: foodToEdit.map { Self.editableNumber($0.fatPer100) } ?? "")
        _sugar = State(initialValue: foodToEdit.map { Self.editableNumber($0.sugarPer100) } ?? "")
        _fiber = State(initialValue: foodToEdit.map { Self.editableNumber($0.fiberPer100) } ?? "")
        _saturatedFat = State(initialValue: foodToEdit.map { Self.editableNumber($0.saturatedFatPer100) } ?? "")
        _salt = State(initialValue: foodToEdit.map { Self.editableNumber($0.saltPer100) } ?? "")
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            nutrientValues != nil &&
            pieceWeightIsValid
    }

    private var pieceWeightValue: Double? {
        let trimmedValue = pieceWeight.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return nil }
        return parseNumber(trimmedValue)
    }

    private var pieceWeightIsValid: Bool {
        pieceWeight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            (pieceWeightValue ?? -1) >= 0
    }

    private var nutrientValues: [Double]? {
        let values = [calories, protein, carbohydrates, fat, sugar, fiber, saturatedFat, salt]
            .map(parseNumber)
        guard values.allSatisfy({ $0 != nil && $0! >= 0 }) else { return nil }
        return values.compactMap { $0 }
    }

    // MARK: - Ansicht

    var body: some View {
        NavigationStack {
            Form {
                Section("Beschreibung") {
                    TextField("Name", text: $name)
                    TextField("Marke (optional)", text: $brand)
                    Picker("Basis", selection: $unit) {
                        Text("Gramm").tag("g")
                        Text("Milliliter").tag("ml")
                    }

                    TextField("Gewicht pro Stück (optional)", text: $pieceWeight)
                        .keyboardType(.decimalPad)
                    Text("Damit kann das Lebensmittel später auch als Stück erfasst werden.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Nährwerte pro 100 \(unit)") {
                    nutrientField("Kalorien", text: $calories, unit: "kcal")
                    nutrientField("Eiweiß", text: $protein, unit: "g")
                    nutrientField("Kohlenhydrate", text: $carbohydrates, unit: "g")
                    nutrientField("Fett", text: $fat, unit: "g")
                    nutrientField("Zucker", text: $sugar, unit: "g")
                    nutrientField("Ballaststoffe", text: $fiber, unit: "g")
                    nutrientField("Gesättigte Fettsäuren", text: $saturatedFat, unit: "g")
                    nutrientField("Salz", text: $salt, unit: "g")
                }
            }
            .navigationTitle(foodToEdit == nil ? "Eigenes Lebensmittel" : "Lebensmittel bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern", action: save)
                        .disabled(!canSave)
                }
            }
            .alert(
                "Lebensmittel konnte nicht gespeichert werden",
                isPresented: Binding(
                    get: { saveErrorMessage != nil },
                    set: { if !$0 { saveErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { saveErrorMessage = nil }
            } message: {
                Text(saveErrorMessage ?? "Unbekannter Speicherfehler.")
            }
        }
    }

    // MARK: - Eingabefelder

    private func nutrientField(_ title: String, text: Binding<String>, unit: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0,0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 72)
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }

    private func parseNumber(_ value: String) -> Double? {
        guard let number = Double(value.replacingOccurrences(of: ",", with: ".")),
              number.isFinite else { return nil }
        return number
    }

    // MARK: - Speichern

    private func save() {
        guard let values = nutrientValues,
              pieceWeightIsValid else { return }
        let customFood = foodToEdit ?? CustomFood(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            brand: brand,
            unit: unit,
            pieceWeight: pieceWeightValue,
            caloriesPer100: values[0],
            proteinPer100: values[1],
            carbohydratesPer100: values[2],
            fatPer100: values[3],
            sugarPer100: values[4],
            fiberPer100: values[5],
            saturatedFatPer100: values[6],
            saltPer100: values[7]
        )

        if foodToEdit != nil {
            customFood.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            customFood.brand = brand
            customFood.unit = unit
            customFood.pieceWeight = pieceWeightValue ?? 0
            customFood.caloriesPer100 = values[0]
            customFood.proteinPer100 = values[1]
            customFood.carbohydratesPer100 = values[2]
            customFood.fatPer100 = values[3]
            customFood.sugarPer100 = values[4]
            customFood.fiberPer100 = values[5]
            customFood.saturatedFatPer100 = values[6]
            customFood.saltPer100 = values[7]
            customFood.updatedAt = .now
        } else {
            modelContext.insert(customFood)
        }

        do {
            try modelContext.save()
            onSaved(customFood.nutritionFood)
            dismiss()
        } catch {
            if foodToEdit == nil {
                modelContext.delete(customFood)
            } else {
                modelContext.rollback()
            }
            saveErrorMessage = error.localizedDescription
        }
    }

    private static func editableNumber(_ value: Double) -> String {
        String(format: "%.2f", value)
            .replacingOccurrences(of: ".00", with: "")
            .replacingOccurrences(of: ".", with: ",")
    }
}

#Preview {
    AddCustomFoodView { _ in }
        .modelContainer(for: [CustomFood.self], inMemory: true)
}
