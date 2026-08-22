import SwiftUI
import SwiftData

// MARK: - AddCustomFoodView

/// Erfasst ein persönliches Lebensmittel inklusive vollständiger Nährwerte.
struct AddCustomFoodView: View {

    // MARK: - Abhängigkeiten

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // MARK: - Eingaben

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
            .navigationTitle("Eigenes Lebensmittel")
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
        let customFood = CustomFood(
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

        modelContext.insert(customFood)
        do {
            try modelContext.save()
            onSaved(customFood.nutritionFood)
            dismiss()
        } catch {
            modelContext.delete(customFood)
            saveErrorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AddCustomFoodView { _ in }
        .modelContainer(for: [CustomFood.self], inMemory: true)
}
