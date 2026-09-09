import SwiftUI
import SwiftData

struct RecipeEditorView: View {
    @Environment(\.elyraAccentColor) private var accentColor
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecipeBook.createdAt) private var recipeBooks: [RecipeBook]
    @Query private var memberships: [RecipeBookMembership]
    @Query private var existingRecipes: [Recipe]
    @Query(sort: \CustomFood.name) private var customFoods: [CustomFood]
    @Query(sort: \FavoriteFood.updatedAt, order: .reverse) private var favoriteFoods: [FavoriteFood]

    let recipe: Recipe?
    @State private var title: String
    @State private var note: String
    @State private var servings: Int
    @State private var prepMinutes: Int
    @State private var category: String
    @State private var imageURL: String
    @State private var sourceURL: String
    @State private var ingredients: [IngredientDraft]
    @State private var steps: [StepDraft]
    @State private var errorMessage: String?
    @State private var importURL = ""
    @State private var isImporting = false
    @State private var selectedBookIDs = Set<UUID>()
    @State private var caloriesPerServingText = ""
    @State private var proteinPerServingText = ""
    @State private var carbohydratesPerServingText = ""
    @State private var fatPerServingText = ""
    @State private var nutritionMessage: String?

    @MainActor init(recipe: Recipe? = nil, ingredients: [RecipeIngredient] = [], steps: [RecipeStep] = []) {
        self.recipe = recipe
        _title = State(initialValue: recipe?.title ?? "")
        _note = State(initialValue: recipe?.note ?? "")
        _servings = State(initialValue: recipe?.servings ?? 2)
        _prepMinutes = State(initialValue: recipe?.prepMinutes ?? 0)
        _category = State(initialValue: recipe?.category ?? "")
        _imageURL = State(initialValue: recipe?.imageURL ?? "")
        _sourceURL = State(initialValue: recipe?.sourceURL ?? "")
        _caloriesPerServingText = State(initialValue: recipe.map { Self.number($0.caloriesPerServing) } ?? "")
        _proteinPerServingText = State(initialValue: recipe.map { Self.number($0.proteinPerServing) } ?? "")
        _carbohydratesPerServingText = State(initialValue: recipe.map { Self.number($0.carbohydratesPerServing) } ?? "")
        _fatPerServingText = State(initialValue: recipe.map { Self.number($0.fatPerServing) } ?? "")
        _ingredients = State(initialValue: ingredients.sorted { $0.position < $1.position }.map(IngredientDraft.init))
        _steps = State(initialValue: steps.sorted { $0.position < $1.position }.map(StepDraft.init))
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        ingredients.contains { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } &&
        steps.contains { !$0.instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
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
                    Stepper("Portionen: \(servings)", value: $servings, in: 1...50)
                    Stepper("Zubereitungszeit: \(prepMinutes) Min.", value: $prepMinutes, in: 0...600, step: 5)
                    TextField("Kategorie (optional)", text: $category)
                    TextField("Notiz (optional)", text: $note, axis: .vertical)
                    TextField("Bild-URL (optional)", text: $imageURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                    TextField("Quelle (URL, optional)", text: $sourceURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }

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
                                    Image(systemName: selectedBookIDs.contains(book.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedBookIDs.contains(book.id) ? accentColor : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

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
            .overlay { if isImporting { SwiftUI.ProgressView("Rezept wird importiert…").padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) } }
            .onAppear {
                if let recipe {
                    selectedBookIDs = Set(memberships.filter { $0.recipeID == recipe.id }.map(\.bookID))
                }
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if recipe == nil, existingRecipes.contains(where: { $0.title.compare(trimmedTitle, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            errorMessage = "Ein Rezept mit diesem Namen existiert bereits."
            return
        }
        let validIngredients = ingredients.enumerated().compactMap { index, draft -> IngredientDraft? in
            guard !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return draft.withPosition(index)
        }
        let validSteps = steps
            .map { StepDraft(instruction: $0.instruction.trimmingCharacters(in: .whitespacesAndNewlines), durationSeconds: $0.durationSeconds) }
            .filter { !$0.instruction.isEmpty }

        let savedRecipe: Recipe
        if let recipe {
            savedRecipe = recipe
            savedRecipe.title = trimmedTitle
            savedRecipe.note = note
            savedRecipe.servings = servings
            savedRecipe.prepMinutes = prepMinutes
            savedRecipe.category = category
            savedRecipe.imageURL = imageURL
            savedRecipe.sourceURL = sourceURL
            savedRecipe.caloriesPerServing = parsed(caloriesPerServingText)
            savedRecipe.proteinPerServing = parsed(proteinPerServingText)
            savedRecipe.carbohydratesPerServing = parsed(carbohydratesPerServingText)
            savedRecipe.fatPerServing = parsed(fatPerServingText)
            savedRecipe.updatedAt = .now
            do {
                let recipeID = recipe.id
                let descriptor = FetchDescriptor<RecipeIngredient>(predicate: #Predicate { $0.recipeID == recipeID })
                try modelContext.fetch(descriptor).forEach(modelContext.delete)
                let stepDescriptor = FetchDescriptor<RecipeStep>(predicate: #Predicate { $0.recipeID == recipeID })
                try modelContext.fetch(stepDescriptor).forEach(modelContext.delete)
                let membershipDescriptor = FetchDescriptor<RecipeBookMembership>(predicate: #Predicate { $0.recipeID == recipeID })
                try modelContext.fetch(membershipDescriptor).forEach(modelContext.delete)
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        } else {
            savedRecipe = Recipe(title: trimmedTitle, servings: servings, prepMinutes: prepMinutes, category: category, imageURL: imageURL, sourceURL: sourceURL)
            savedRecipe.note = note
            savedRecipe.caloriesPerServing = parsed(caloriesPerServingText)
            savedRecipe.proteinPerServing = parsed(proteinPerServingText)
            savedRecipe.carbohydratesPerServing = parsed(carbohydratesPerServingText)
            savedRecipe.fatPerServing = parsed(fatPerServingText)
            modelContext.insert(savedRecipe)
        }

        for (index, ingredient) in validIngredients.enumerated() {
            modelContext.insert(RecipeIngredient(recipeID: savedRecipe.id, name: ingredient.name, amount: ingredient.amount, unit: ingredient.unit, position: index))
        }
        for (index, step) in validSteps.enumerated() {
            modelContext.insert(RecipeStep(recipeID: savedRecipe.id, instruction: step.instruction, position: index, durationSeconds: step.durationSeconds))
        }
        for bookID in selectedBookIDs {
            modelContext.insert(RecipeBookMembership(recipeID: savedRecipe.id, bookID: bookID))
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func stepRow(step: Binding<StepDraft>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Text(String(step.wrappedValue.position + 1))
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 24)
                TextField("Zubereitungsschritt", text: step.instruction, axis: .vertical)
            }
            Stepper(
                step.wrappedValue.durationSeconds == 0
                    ? "Kein Schritt-Timer"
                    : "Schritt-Timer: \(step.wrappedValue.durationSeconds / 60) Min.",
                value: Binding(
                    get: { step.wrappedValue.durationSeconds / 60 },
                    set: { step.wrappedValue.durationSeconds = max(0, $0 * 60) }
                ),
                in: 0...180
            )
            .font(.caption)
        }
    }

    private func nutrientTextField(_ title: String, text: Binding<String>, unit: String) -> some View {
        HStack {
            TextField(title, text: text).keyboardType(.decimalPad)
            Text(unit).foregroundStyle(.secondary)
        }
    }

    private func parsed(_ value: String) -> Double {
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
            : "(totals.unrecognizedIngredients) Zutat(en) konnten nicht zugeordnet werden und müssen geprüft werden."
    }

    private static func number(_ value: Double) -> String {
        value == 0 ? "" : value.formatted(.number.precision(.fractionLength(0...2)))
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
                    ingredients = imported.ingredients.map { IngredientDraft(amount: $0.amount, unit: $0.unit, name: $0.name) }
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

    private var errorPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }
}

private struct StepDraft: Identifiable {
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

private struct IngredientDraft: Identifiable {
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

    func withPosition(_ position: Int) -> IngredientDraft { self }
}
