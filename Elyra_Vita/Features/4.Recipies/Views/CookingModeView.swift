import PasukiUI
import SwiftData
import SwiftUI

struct CookingModeView: View {
    @Environment(\.elyraAccentColor) var accentColor
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    let recipe: Recipe
    let ingredients: [RecipeIngredient]
    let steps: [RecipeStep]
    @State var currentStep = 0
    @State var remainingSeconds = 0
    @State var timerRunning = false
    @State var customTimerSheetPresented = false
    @State var scannerPresented = false
    @State var scannedProducts: [ScannedCookingProduct] = []
    @State var scanMessage: String?
    @State var completionSheetPresented = false
    @State var checkedIngredientIDs = Set<UUID>()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text(recipe.title).font(.title2.weight(.bold)).multilineTextAlignment(.center)
                    SwiftUI.ProgressView(value: Double(currentStep + 1), total: Double(max(steps.count, 1)))
                        .tint(accentColor)
                    HStack {
                        Button { scannerPresented = true } label: {
                            Label("Produkt scannen", systemImage: "barcode.viewfinder")
                        }
                        .buttonStyle(.borderedProminent).tint(accentColor)
                        Spacer()
                        Text("\(scannedProducts.count) erfasst")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }

                    if !scannedProducts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Verwendete Produkte").font(.headline)
                            ForEach($scannedProducts) { $product in
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(product.food.name).font(.subheadline.weight(.semibold))
                                        if ingredients.isEmpty {
                                            Text("Keine Rezeptzutaten vorhanden")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Picker("Rezeptzutat", selection: $product.matchedIngredient) {
                                                Text("Nicht zugeordnet").tag("")
                                                ForEach(
                                                    ingredients.sorted { $0.position < $1.position }
                                                ) { ingredient in
                                                    Text(ingredient.name).tag(ingredient.name)
                                                }
                                            }
                                            .font(.caption)
                                            .tint(product.matchedIngredient.isEmpty ? .orange : .secondary)
                                        }
                                    }
                                    Spacer()
                                    TextField("Menge", text: $product.amountText)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 58)
                                    Text(product.unit).foregroundStyle(.secondary)
                                }
                            }
                            Button("Alle als gegessen eintragen") { saveScannedProducts() }
                                .buttonStyle(.bordered)
                        }
                        .padding(14)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }

                    if !ingredients.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Zutaten").font(.headline)
                                Spacer()
                                Text("\(checkedIngredientIDs.count)/\(ingredients.count)")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            ForEach(ingredients.sorted { $0.position < $1.position }) { ingredient in
                                Button {
                                    if checkedIngredientIDs.contains(ingredient.id) {
                                        checkedIngredientIDs.remove(ingredient.id)
                                    } else {
                                        checkedIngredientIDs.insert(ingredient.id)
                                    }
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(
                                            systemName: checkedIngredientIDs.contains(ingredient.id)
                                                ? "checkmark.circle.fill" : "circle"
                                        )
                                        .foregroundStyle(
                                            checkedIngredientIDs.contains(ingredient.id) ? .green : .secondary
                                        )
                                        Text(
                                            [ingredient.amount, ingredient.unit, ingredient.name]
                                                .filter { !$0.isEmpty }
                                                .joined(separator: " ")
                                        )
                                        .strikethrough(checkedIngredientIDs.contains(ingredient.id))
                                        .foregroundStyle(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(14)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                    if steps.isEmpty {
                        Text("Keine Zubereitungsschritte vorhanden.").foregroundStyle(.secondary)
                    } else {
                        Text("Schritt \(currentStep + 1) von \(steps.count)")
                            .font(.headline).foregroundStyle(.secondary)
                        Text(steps.sorted { $0.position < $1.position }[currentStep].instruction)
                            .font(.title3).multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity)
                        if remainingSeconds > 0 {
                            Text(timerText)
                                .font(.system(size: 42, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                        }
                        HStack {
                            Button("Zurück") { currentStep = max(0, currentStep - 1) }
                                .disabled(currentStep == 0)
                            Spacer()
                            Button(currentStep == steps.count - 1 ? "Fertig" : "Weiter") {
                                if currentStep == steps.count - 1 {
                                    dismiss()
                                } else {
                                    currentStep += 1
                                }
                            }
                            .buttonStyle(.borderedProminent).tint(accentColor)
                        }
                        if timerRunning {
                            Button("Schritt-Timer stoppen") { stopTimer() }
                                .foregroundStyle(.red)
                        } else if currentStepDuration > 0 {
                            Button("Schritt-Timer starten (\(currentStepDuration / 60) Min.)") {
                                startTimer(seconds: currentStepDuration)
                            }
                        } else {
                            Button("Eigenen Timer für diesen Schritt einstellen") {
                                customTimerSheetPresented = true
                            }
                        }
                        Button("Kochen abschließen") { completionSheetPresented = true }
                            .buttonStyle(.borderedProminent).tint(.green)
                    }
                }
                .padding(24)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Kochmodus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
            .fullScreenCover(isPresented: $scannerPresented) {
                BarcodeScannerView(
                    onBarcode: { barcode in
                        scannerPresented = false
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(350))
                            await loadProduct(barcode: barcode)
                        }
                    },
                    onUnavailable: {
                        scannerPresented = false
                        scanMessage = "Der Barcode-Scanner ist auf diesem Gerät nicht verfügbar."
                    }
                )
                .ignoresSafeArea()
            }
            .alert("Produkt scannen", isPresented: scanMessagePresented) {
                Button("OK", role: .cancel) { scanMessage = nil }
            } message: {
                Text(scanMessage ?? "")
            }
            .sheet(isPresented: $completionSheetPresented) {
                CookingCompletionSheet(defaultServings: recipe.servings) { portions in
                    finishCooking(portions: portions)
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $customTimerSheetPresented) {
                CustomStepTimerSheet { seconds in
                    startTimer(seconds: seconds)
                }
                .presentationDetents([.medium])
            }
            .task(id: timerRunning) {
                guard timerRunning else { return }
                while remainingSeconds > 0 {
                    try? await Task.sleep(for: .seconds(1))
                    remainingSeconds -= 1
                }
                timerRunning = false
            }
        }
    }
}
