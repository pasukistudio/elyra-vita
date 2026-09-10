import SwiftData
import SwiftUI

struct RecipeEditorView: View {
    @Environment(\.elyraAccentColor) private var accentColor
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Query(sort: \RecipeBook.createdAt) private var recipeBooks: [RecipeBook]
    @Query private var memberships: [RecipeBookMembership]
    @Query var existingRecipes: [Recipe]
    @Query(sort: \CustomFood.name) private var customFoods: [CustomFood]
    @Query(sort: \FavoriteFood.updatedAt, order: .reverse) private var favoriteFoods: [FavoriteFood]

    let recipe: Recipe?
    @State var title: String
    @State var note: String
    @State var servings: Int
    @State var prepMinutes: Int
    @State var category: String
    @State var imageURL: String
    @State var sourceURL: String
    @State var ingredients: [IngredientDraft]
    @State var steps: [StepDraft]
    @State var errorMessage: String?
    @State private var importURL = ""
    @State private var isImporting = false
    @State var selectedBookIDs = Set<UUID>()
    @State var caloriesPerServingText = ""
    @State var proteinPerServingText = ""
    @State var carbohydratesPerServingText = ""
    @State var fatPerServingText = ""
    @State var nutritionMessage: String?

    @MainActor init(
        recipe: Recipe? = nil,
        ingredients: [RecipeIngredient] = [],
        steps: [RecipeStep] = [],
        defaultTitle: String = "",
        defaultServings: Int = 2,
        prefilledNutrition: RecipeNutritionTotals? = nil
    ) {
        self.recipe = recipe
        _title = State(initialValue: recipe?.title ?? defaultTitle)
        _note = State(initialValue: recipe?.note ?? "")
        _servings = State(initialValue: recipe?.servings ?? defaultServings)
        _prepMinutes = State(initialValue: recipe?.prepMinutes ?? 0)
        _category = State(initialValue: recipe?.category ?? "")
        _imageURL = State(initialValue: recipe?.imageURL ?? "")
        _sourceURL = State(initialValue: recipe?.sourceURL ?? "")
        _caloriesPerServingText = State(
            initialValue: recipe.map { Self.number($0.caloriesPerServing) }
                ?? prefilledNutrition.map { Self.number($0.calories) }
                ?? ""
        )
        _proteinPerServingText = State(
            initialValue: recipe.map { Self.number($0.proteinPerServing) }
                ?? prefilledNutrition.map { Self.number($0.protein) }
                ?? ""
        )
        _carbohydratesPerServingText = State(
            initialValue: recipe.map { Self.number($0.carbohydratesPerServing) }
                ?? prefilledNutrition.map { Self.number($0.carbohydrates) }
                ?? ""
        )
        _fatPerServingText = State(
            initialValue: recipe.map { Self.number($0.fatPerServing) }
                ?? prefilledNutrition.map { Self.number($0.fat) }
                ?? ""
        )
        _ingredients = State(initialValue: ingredients.sorted { $0.position < $1.position }.map(IngredientDraft.init))
        _steps = State(initialValue: steps.sorted { $0.position < $1.position }.map(StepDraft.init))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Rezept-URL", text: $importURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                    Button {
                        importRecipe()
                    } label: {
                        Label("Rezept aus URL importieren", systemImage: "link.badge.plus")
                    }
                    .disabled(importURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isImporting)
                } header: {
                    Text("Schnellstart")
                } footer: {
                    Text("Die importierten Angaben kannst du vor dem Speichern bearbeiten.")
                }

                Section("Rezept") {
                    TextField("Name", text: $title)
                    Stepper("Portionen: \(servings)", value: $servings, in: 1 ... 50)
                    Stepper("Zubereitungszeit: \(prepMinutes) Min.", value: $prepMinutes, in: 0 ... 600, step: 5)
                    TextField("Kategorie (optional)", text: $category)
                    TextField("Notiz (optional)", text: $note, axis: .vertical)
                    TextField("Bild-URL (optional)", text: $imageURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                    TextField("Quelle (URL, optional)", text: $sourceURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }

                recipeBookSection

                Section("Nährwerte pro Portion (optional)") {
                    nutrientTextField("Kalorien", text: $caloriesPerServingText, unit: "kcal")
                    nutrientTextField("Eiweiß", text: $proteinPerServingText, unit: "g")
                    nutrientTextField("Kohlenhydrate", text: $carbohydratesPerServingText, unit: "g")
                    nutrientTextField("Fett", text: $fatPerServingText, unit: "g")
                    Button {
                        calculateNutrition()
                    } label: {
                        Label("Nährwerte aus Zutaten berechnen", systemImage: "function")
                    }
                    if let nutritionMessage {
                        Text(nutritionMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    ForEach($ingredients) { $ingredient in
                        HStack(spacing: 8) {
                            TextField("Menge", text: $ingredient.amount)
                                .frame(width: 72)
                            TextField("Einheit", text: $ingredient.unit)
                                .frame(width: 72)
                            TextField("Lebensmittel", text: $ingredient.name)
                        }
                    }
                    .onDelete { ingredients.remove(atOffsets: $0) }

                    Button { ingredients.append(IngredientDraft()) } label: {
                        Label("Zutat hinzufügen", systemImage: "plus")
                    }
                } header: {
                    Text("Zutaten")
                }

                Section {
                    ForEach($steps) { $step in
                        stepRow(step: $step)
                    }
                    .onDelete { steps.remove(atOffsets: $0) }

                    Button { steps.append(StepDraft(position: steps.count)) } label: {
                        Label("Schritt hinzufügen", systemImage: "plus")
                    }
                } header: {
                    Text("Zubereitung")
                }
            }
            .navigationTitle(recipe == nil ? "Neues Rezept" : "Rezept bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                        .disabled(!canSave)
                }
            }
            .alert("Rezept konnte nicht gespeichert werden", isPresented: errorPresented) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Bitte versuche es erneut.")
            }
            .overlay {
                if isImporting {
                    SwiftUI.ProgressView("Rezept wird importiert…")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .onAppear {
                if let recipe {
                    selectedBookIDs = Set(memberships.filter { $0.recipeID == recipe.id }.map(\.bookID))
                }
            }
        }
    }

    func parsed(_ value: String) -> Double {
        Double(value.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func calculateNutrition() {
        var foods = NutritionFood.localCatalog + customFoods.map(\.nutritionFood) + favoriteFoods.map(\.nutritionFood)
        var seenIDs = Set<String>()
        foods = foods.filter { seenIDs.insert($0.id).inserted }
        let values = ingredients.map { RecipeIngredientValue(amount: $0.amount, unit: $0.unit, name: $0.name) }
        let totals = RecipeNutritionCalculator().calculate(ingredients: values, foods: foods, servings: servings)
        guard totals.recognizedIngredients > 0 else {
            nutritionMessage = "Keine Zutat konnte automatisch zugeordnet werden."
            return
        }
        caloriesPerServingText = Self.number(totals.calories)
        proteinPerServingText = Self.number(totals.protein)
        carbohydratesPerServingText = Self.number(totals.carbohydrates)
        fatPerServingText = Self.number(totals.fat)
        nutritionMessage = totals.unrecognizedIngredients == 0
            ? "Alle Zutaten wurden berücksichtigt."
            : "\(totals.unrecognizedIngredients) Zutat(en) konnten nicht zugeordnet werden und müssen geprüft werden."
    }

    private static func number(_ value: Double) -> String {
        value == 0 ? "" : value.formatted(.number.precision(.fractionLength(0 ... 2)))
    }

    private func importRecipe() {
        isImporting = true
        Task {
            do {
                let imported = try await RecipeImportService().importRecipe(from: importURL)
                await MainActor.run {
                    title = imported.title
                    note = imported.note
                    category = imported.category
                    imageURL = imported.imageURL
                    sourceURL = importURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    servings = imported.servings
                    prepMinutes = imported.prepMinutes
                    ingredients = imported.ingredients.map {
                        IngredientDraft(amount: $0.amount, unit: $0.unit, name: $0.name)
                    }
                    steps = imported.steps.map { StepDraft(instruction: $0) }
                    isImporting = false
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

private extension RecipeEditorView {
    var recipeBookSection: some View {
        Section("Rezeptbücher") {
            if recipeBooks.isEmpty {
                Text("Noch keine Rezeptbücher angelegt.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recipeBooks) { book in
                    Button {
                        if selectedBookIDs.contains(book.id) {
                            selectedBookIDs.remove(book.id)
                        } else {
                            selectedBookIDs.insert(book.id)
                        }
                    } label: {
                        HStack {
                            Label(book.name, systemImage: "book")
                            Spacer()
                            Image(
                                systemName: selectedBookIDs.contains(book.id)
                                    ? "checkmark.circle.fill"
                                    : "circle"
                            )
                            .foregroundStyle(selectedBookIDs.contains(book.id) ? accentColor : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct StepDraft: Identifiable {
    let id = UUID()
    var instruction = ""
    var durationSeconds = 0
    var position = 0

    init(instruction: String = "", durationSeconds: Int = 0, position: Int = 0) {
        self.instruction = instruction
        self.durationSeconds = max(0, durationSeconds)
        self.position = position
    }

    init(_ step: RecipeStep) {
        instruction = step.instruction
        durationSeconds = step.durationSeconds
        position = step.position
    }
}

struct IngredientDraft: Identifiable {
    let id = UUID()
    var amount = ""
    var unit = ""
    var name = ""

    init(amount: String = "", unit: String = "", name: String = "") {
        self.amount = amount
        self.unit = unit
        self.name = name
    }

    init(_ ingredient: RecipeIngredient) {
        amount = ingredient.amount
        unit = ingredient.unit
        name = ingredient.name
    }

    func withPosition(_: Int) -> IngredientDraft {
        self
    }
}
