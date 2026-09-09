import PasukiUI
import SwiftData
import SwiftUI

struct RecipesView: View {
    @Environment(\.elyraAccentColor) private var accentColor
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recipe.updatedAt, order: .reverse) private var recipes: [Recipe]
    @Query private var ingredients: [RecipeIngredient]
    @Query private var steps: [RecipeStep]
    @Query(sort: \RecipeBook.createdAt) private var recipeBooks: [RecipeBook]
    @Query private var memberships: [RecipeBookMembership]
    @State private var showingEditor = false
    @State private var showingFilterSheet = false
    @State private var showingBooksSheet = false
    @State private var editingRecipe: Recipe?
    @State private var deletingRecipe: Recipe?
    @State private var ingredientFilter = ""
    @State private var matchAllIngredients = false
    @State private var maximumMinutes: Int?
    @State private var searchText = ""
    @State private var sortOption: RecipeSort = .recent

    private var filteredRecipes: [Recipe] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = query.isEmpty ? recipes : recipes.filter { recipe in
            recipe.title.localizedCaseInsensitiveContains(query) ||
                ingredients.filter { $0.recipeID == recipe.id }.contains { $0.name.localizedCaseInsensitiveContains(query) }
        }
        let sorted: [Recipe]
        switch sortOption {
        case .recent: sorted = matching.sorted { $0.updatedAt > $1.updatedAt }
        case .title: sorted = matching.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .time: sorted = matching.sorted { $0.prepMinutes < $1.prepMinutes }
        }
        return filteredByDetails(sorted)
    }

    private func filteredByDetails(_ candidates: [Recipe]) -> [Recipe] {
        let terms = ingredientFilter.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return candidates.filter { recipe in
            if let maximumMinutes, recipe.prepMinutes > maximumMinutes {
                return false
            }
            guard !terms.isEmpty else { return true }
            let names = ingredients.filter { $0.recipeID == recipe.id }.map { $0.name }
            let matches = terms.map { term in names.contains { $0.localizedCaseInsensitiveContains(term) } }
            return matchAllIngredients ? matches.allSatisfy { $0 } : matches.contains { $0 }
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    Text("Rezepte")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Button { showingFilterSheet = true } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(accentColor)
                            .frame(width: 56, height: 56)
                            .background(accentColor.opacity(0.14), in: Circle())
                    }
                    .accessibilityLabel("Rezepte filtern")
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Text("Meine Kochbücher")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                filterBar

                if filteredRecipes.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredRecipes) { recipe in
                                NavigationLink {
                                    RecipeDetailView(recipe: recipe, ingredients: ingredients.filter { $0.recipeID == recipe.id }, steps: steps.filter { $0.recipeID == recipe.id })
                                } label: {
                                    recipeCard(recipe)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Favorit umschalten", systemImage: recipe.isFavorite ? "heart.slash" : "heart") { toggleFavorite(recipe) }
                                    Button("Bearbeiten", systemImage: "pencil") { editingRecipe = recipe }
                                    Button("Löschen", systemImage: "trash", role: .destructive) { deletingRecipe = recipe }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 100)
                    }
                    .scrollIndicators(.hidden)
                }
            }

            ElyraFloatingActionButton(
                accessibilityLabel: "Neues Rezept",
                action: { showingEditor = true }
            )
            .padding(.trailing, 22)
            .padding(.bottom, 18)
        }
        .sheet(isPresented: $showingEditor) { RecipeEditorView() }
        .sheet(isPresented: $showingFilterSheet) {
            RecipeFilterSheet(
                ingredientFilter: $ingredientFilter,
                matchAllIngredients: $matchAllIngredients,
                maximumMinutes: $maximumMinutes
            )
        }
        .sheet(isPresented: $showingBooksSheet) { RecipeBooksView() }
        .sheet(item: $editingRecipe) { recipe in
            RecipeEditorView(recipe: recipe, ingredients: ingredients.filter { $0.recipeID == recipe.id }, steps: steps.filter { $0.recipeID == recipe.id })
        }
        .alert("Rezept löschen?", isPresented: deletingPresented, presenting: deletingRecipe) { recipe in
            Button("Löschen", role: .destructive) { delete(recipe) }
            Button("Abbrechen", role: .cancel) { deletingRecipe = nil }
        } message: { recipe in
            Text("\"\(recipe.title)\" wird dauerhaft entfernt.")
        }
        .searchable(text: $searchText, prompt: "Rezepte oder Zutaten suchen")
        .appBackground()
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button {} label: {
                    Label("Alle", systemImage: "books.vertical")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(accentColor, in: Capsule())
                }
                .buttonStyle(.plain)
                ForEach(recipeBooks) { book in
                    bookButton(book)
                }
                Button { showingBooksSheet = true } label: {
                    Image(systemName: "plus")
                        .frame(width: 36, height: 36)
                        .background(Color.secondary.opacity(0.12), in: Circle())
                }
                .accessibilityLabel("Rezeptbuch anlegen")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    private func bookButton(_ book: RecipeBook) -> some View {
        NavigationLink {
            RecipeBookDetailView(book: book)
        } label: {
            Label(book.name, systemImage: "book")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "fork.knife.circle.fill").font(.system(size: 42)).foregroundStyle(.orange)
            Text(recipes.isEmpty ? "Noch keine Rezepte" : "Keine Rezepte in diesem Rezeptbuch")
                .font(.title3.weight(.bold))
            Text("Speichere deine Lieblingsrezepte mit Zutaten und Zubereitung.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if recipes.isEmpty {
                Button("Rezept anlegen") { showingEditor = true }.buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
    }

    private func recipeCard(_ recipe: Recipe) -> some View {
        HStack(spacing: 14) {
            recipeImage(recipe, size: 88)
            VStack(alignment: .leading, spacing: 7) {
                Text(recipe.title).font(.headline).foregroundStyle(.primary).multilineTextAlignment(.leading)
                if !recipe.category.isEmpty {
                    Text(recipe.category).font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 14) {
                    Label("\(recipe.servings)", systemImage: "person.2")
                    if recipe.prepMinutes > 0 {
                        Label("\(recipe.prepMinutes) Min.", systemImage: "clock")
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { Rectangle().fill(.quaternary).frame(height: 1).padding(.leading, 102) }
    }

    @ViewBuilder
    private func recipeImage(_ recipe: Recipe, size: CGFloat) -> some View {
        if let url = URL(string: recipe.imageURL), !recipe.imageURL.isEmpty {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    placeholderImage
                }
            }
            .frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            placeholderImage.frame(width: size, height: size)
        }
    }

    private var placeholderImage: some View {
        Image(systemName: "fork.knife").font(.title2).foregroundStyle(.orange)
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(.orange.opacity(0.12))
    }

    private func toggleFavorite(_ recipe: Recipe) {
        recipe.isFavorite.toggle(); recipe.updatedAt = .now
        _ = PersistenceErrorReporter.save(modelContext, operation: "Rezeptfavorit ändern")
    }

    private func delete(_ recipe: Recipe) {
        ingredients.filter { $0.recipeID == recipe.id }.forEach { modelContext.delete($0) }
        steps.filter { $0.recipeID == recipe.id }.forEach { modelContext.delete($0) }
        memberships.filter { $0.recipeID == recipe.id }.forEach { modelContext.delete($0) }
        modelContext.delete(recipe)
        if PersistenceErrorReporter.save(modelContext, operation: "Rezept löschen") {
            deletingRecipe = nil
        }
    }

    private var deletingPresented: Binding<Bool> {
        Binding(get: { deletingRecipe != nil }, set: {
            if !$0 {
                deletingRecipe = nil
            }
        })
    }
}

private struct RecipeFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var ingredientFilter: String
    @Binding var matchAllIngredients: Bool
    @Binding var maximumMinutes: Int?

    var body: some View {
        NavigationStack {
            Form {
                Section("Gewünschte Zutaten") {
                    TextField("Zum Beispiel: Nudeln, Erbsen", text: $ingredientFilter)
                    Picker("Übereinstimmung", selection: $matchAllIngredients) {
                        Text("Eine der Zutaten").tag(false)
                        Text("Alle Zutaten").tag(true)
                    }
                    .pickerStyle(.segmented)
                    Text("Mehrere Zutaten mit Komma trennen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Weitere Filter") {
                    Picker("Maximale Zeit", selection: $maximumMinutes) {
                        Text("Beliebig").tag(Int?.none)
                        Text("30 Min.").tag(Int?.some(30))
                        Text("60 Min.").tag(Int?.some(60))
                    }
                    Button("Alle Filter zurücksetzen", role: .destructive) {
                        ingredientFilter = ""
                        matchAllIngredients = false
                        maximumMinutes = nil
                    }
                }
            }
            .navigationTitle("Rezepte filtern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private enum RecipeSort: String, CaseIterable, Identifiable {
    case recent, title, time
    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .recent: "Zuletzt geändert"
        case .title: "Alphabetisch"
        case .time: "Zubereitungszeit"
        }
    }
}

private struct RecipeBookDetailView: View {
    @Query(sort: \Recipe.updatedAt, order: .reverse) private var recipes: [Recipe]
    @Query private var memberships: [RecipeBookMembership]
    @Query private var ingredients: [RecipeIngredient]
    @Query private var steps: [RecipeStep]
    let book: RecipeBook

    private var bookRecipes: [Recipe] {
        let ids = Set(memberships.filter { $0.bookID == book.id }.map(\.recipeID))
        return recipes.filter { ids.contains($0.id) }
    }

    var body: some View {
        Group {
            if bookRecipes.isEmpty {
                ContentUnavailableView("Noch keine Rezepte", systemImage: "book", description: Text("Füge Rezepte über den Rezepteditor zu diesem Buch hinzu."))
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(bookRecipes) { recipe in
                            NavigationLink {
                                RecipeDetailView(recipe: recipe, ingredients: ingredients.filter { $0.recipeID == recipe.id }, steps: steps.filter { $0.recipeID == recipe.id })
                            } label: {
                                bookRecipeRow(recipe)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle(book.name)
        .navigationBarTitleDisplayMode(.large)
        .appBackground()
    }

    private func bookRecipeRow(_ recipe: Recipe) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "fork.knife")
                .foregroundStyle(.orange)
                .frame(width: 68, height: 68)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 5) {
                Text(recipe.title).font(.headline).foregroundStyle(.primary)
                HStack(spacing: 12) {
                    Label("\(recipe.servings)", systemImage: "person.2")
                    if recipe.prepMinutes > 0 {
                        Label("\(recipe.prepMinutes) Min.", systemImage: "clock")
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { Rectangle().fill(.quaternary).frame(height: 1).padding(.leading, 82) }
    }
}

private struct RecipeDetailView: View {
    @Environment(\.elyraAccentColor) private var accentColor
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShoppingList.updatedAt, order: .reverse) private var shoppingLists: [ShoppingList]
    let recipe: Recipe
    let ingredients: [RecipeIngredient]
    let steps: [RecipeStep]
    @State private var cookingModePresented = false
    @State private var confirmationMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                AsyncImage(url: URL(string: recipe.imageURL)) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        placeholder
                    }
                }
                .frame(height: 230).frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                if !recipe.note.isEmpty {
                    Text(recipe.note).font(.body).padding(18).frame(maxWidth: .infinity, alignment: .leading).background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

                HStack {
                    Label("\(recipe.servings) Portionen", systemImage: "person.2")
                    Spacer()
                    if recipe.prepMinutes > 0 {
                        Label("\(recipe.prepMinutes) Min.", systemImage: "clock")
                    }
                }
                .foregroundStyle(accentColor).padding(18).background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                HStack(spacing: 12) {
                    Button { cookingModePresented = true } label: {
                        Label("Kochmodus", systemImage: "play.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accentColor)
                    Button { logAsEaten() } label: {
                        Label("Gegessen", systemImage: "fork.knife")
                    }
                    .buttonStyle(.bordered)
                    if recipe.caloriesPerServing > 0 {
                        Text("\(recipe.caloriesPerServing.formatted(.number.precision(.fractionLength(0 ... 0)))) kcal / Portion")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                detailSection("Zutaten") {
                    ForEach(ingredients.sorted { $0.position < $1.position }) { ingredient in
                        Text([ingredient.amount, ingredient.unit, ingredient.name].filter { !$0.isEmpty }.joined(separator: " "))
                            .padding(.vertical, 8)
                    }
                    Menu {
                        if shoppingLists.isEmpty {
                            Button("Neue Liste anlegen") { addIngredientsToNewList() }
                        } else {
                            ForEach(shoppingLists) { list in
                                Button(list.name) { addIngredients(to: list) }
                            }
                        }
                    } label: {
                        Label("Zur Einkaufsliste", systemImage: "cart.badge.plus")
                    }
                    .foregroundStyle(accentColor).padding(.top, 8)
                }

                detailSection("Zubereitung") {
                    ForEach(steps.sorted { $0.position < $1.position }) { step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(step.position + 1)").font(.headline).frame(width: 30, height: 30).background(.gray.opacity(0.2), in: Circle())
                            Text(step.instruction).frame(maxWidth: .infinity, alignment: .leading)
                        }.padding(.vertical, 8)
                    }
                }
            }
            .padding(20).padding(.bottom, 40)
        }
        .scrollIndicators(.hidden).background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(recipe.title).navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $cookingModePresented) {
            CookingModeView(recipe: recipe, ingredients: ingredients, steps: steps)
        }
        .alert("Rezept", isPresented: confirmationPresented) {
            Button("OK", role: .cancel) { confirmationMessage = nil }
        } message: {
            Text(confirmationMessage ?? "")
        }
    }

    private func detailSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.weight(.bold)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 0, content: content).padding(18).background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var placeholder: some View {
        Image(systemName: "fork.knife").font(.largeTitle).foregroundStyle(.orange).frame(maxWidth: .infinity, maxHeight: .infinity).background(.orange.opacity(0.12))
    }

    private func addIngredientsToNewList() {
        let list = ShoppingList(name: "Rezeptzutaten")
        modelContext.insert(list)
        addIngredients(to: list)
    }

    private func addIngredients(to list: ShoppingList) {
        for ingredient in ingredients {
            let name = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let amount = Double(ingredient.amount.replacingOccurrences(of: ",", with: ".")) ?? 1
            if let existing = try? modelContext.fetch(FetchDescriptor<ShoppingListItem>()).first(where: {
                $0.listID == list.id && $0.name.caseInsensitiveCompare(name) == .orderedSame && $0.unit == (ingredient.unit.isEmpty ? "Stück" : ingredient.unit)
            }) {
                existing.update(quantity: existing.quantity + amount)
            } else {
                modelContext.insert(ShoppingListItem(listID: list.id, name: name, quantity: amount, unit: ingredient.unit.isEmpty ? "Stück" : ingredient.unit))
            }
        }
        list.updatedAt = .now
        if PersistenceErrorReporter.save(modelContext, operation: "Rezeptzutaten zur Einkaufsliste hinzufügen") {
            confirmationMessage = "Die Zutaten wurden zur Liste „\(list.name)“ hinzugefügt."
        }
    }

    private var confirmationPresented: Binding<Bool> {
        Binding(get: { confirmationMessage != nil }, set: {
            if !$0 {
                confirmationMessage = nil
            }
        })
    }

    private func logAsEaten() {
        modelContext.insert(NutritionEntry(
            foodName: recipe.title,
            mealType: .snack,
            amount: 1,
            unit: "portion",
            calories: recipe.caloriesPerServing,
            proteinGrams: recipe.proteinPerServing,
            carbohydratesGrams: recipe.carbohydratesPerServing,
            fatGrams: recipe.fatPerServing,
            source: "recipe",
            externalFoodID: recipe.id.uuidString
        ))
        if PersistenceErrorReporter.save(modelContext, operation: "Rezept als gegessen eintragen") {
            confirmationMessage = "Das Rezept wurde als gegessen eingetragen."
        }
    }
}

private struct CookingModeView: View {
    @Environment(\.elyraAccentColor) private var accentColor
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let recipe: Recipe
    let ingredients: [RecipeIngredient]
    let steps: [RecipeStep]
    @State private var currentStep = 0
    @State private var remainingSeconds = 0
    @State private var timerRunning = false
    @State private var customTimerSheetPresented = false
    @State private var scannerPresented = false
    @State private var scannedProducts: [ScannedCookingProduct] = []
    @State private var scanMessage: String?
    @State private var completionSheetPresented = false
    @State private var checkedIngredientIDs = Set<UUID>()

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
                                            Text("Keine Rezeptzutaten vorhanden").font(.caption).foregroundStyle(.secondary)
                                        } else {
                                            Picker("Rezeptzutat", selection: $product.matchedIngredient) {
                                                Text("Nicht zugeordnet").tag("")
                                                ForEach(ingredients.sorted { $0.position < $1.position }) { ingredient in
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
                                        Image(systemName: checkedIngredientIDs.contains(ingredient.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(checkedIngredientIDs.contains(ingredient.id) ? .green : .secondary)
                                        Text([ingredient.amount, ingredient.unit, ingredient.name].filter { !$0.isEmpty }.joined(separator: " "))
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
                            Text(timerText).font(.system(size: 42, weight: .semibold, design: .rounded)).monospacedDigit()
                        }
                        HStack {
                            Button("Zurück") { currentStep = max(0, currentStep - 1) }.disabled(currentStep == 0)
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

    private var timerText: String {
        String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60)
    }

    private var currentStepDuration: Int {
        guard !steps.isEmpty, steps.indices.contains(currentStep) else { return 0 }
        return max(0, steps.sorted { $0.position < $1.position }[currentStep].durationSeconds)
    }

    private func startTimer(seconds: Int) {
        remainingSeconds = max(1, seconds)
        timerRunning = true
    }

    private func stopTimer() {
        timerRunning = false
        remainingSeconds = 0
    }

    private func loadProduct(barcode: String) async {
        do {
            guard let food = try await OpenFoodFactsService().product(for: barcode) else {
                scanMessage = "Dieses Produkt wurde nicht gefunden."
                return
            }
            let match = bestIngredientMatch(for: food)
            if let match {
                checkedIngredientIDs.insert(match.id)
            }
            scannedProducts.append(ScannedCookingProduct(food: food, matchedIngredient: match?.name ?? ""))
            scanMessage = match == nil
                ? "\(food.name) wurde erfasst. Bitte ordne das Produkt beim Rezept zu."
                : "\(food.name) wurde \"\(match?.name ?? "")\" zugeordnet."
        } catch {
            scanMessage = "Das Produkt konnte nicht geladen werden. Bitte versuche es erneut."
        }
    }

    private func saveScannedProducts() {
        for product in scannedProducts {
            let amount = Double(product.amountText.replacingOccurrences(of: ",", with: ".")) ?? 100
            let factor = max(amount, 0) / 100
            modelContext.insert(NutritionEntry(
                foodName: product.food.name,
                brand: product.food.brand,
                mealType: .snack,
                amount: max(amount, 0),
                unit: product.unit,
                calories: product.food.caloriesPer100 * factor,
                proteinGrams: product.food.proteinPer100 * factor,
                carbohydratesGrams: product.food.carbohydratesPer100 * factor,
                fatGrams: product.food.fatPer100 * factor,
                sugarGrams: product.food.sugarPer100 * factor,
                fiberGrams: product.food.fiberPer100 * factor,
                saturatedFatGrams: product.food.saturatedFatPer100 * factor,
                saltGrams: product.food.saltPer100 * factor,
                source: product.food.source,
                externalFoodID: product.food.id
            ))
        }
        if PersistenceErrorReporter.save(modelContext, operation: "Gescannte Kochzutaten speichern") {
            scanMessage = "\(scannedProducts.count) Produkt(e) wurden als gegessen eingetragen."
        }
    }

    private func finishCooking(portions: Double) {
        if scannedProducts.isEmpty {
            let multiplier = max(portions, 0)
            modelContext.insert(NutritionEntry(
                foodName: recipe.title,
                mealType: .snack,
                amount: multiplier,
                unit: "portion",
                calories: recipe.caloriesPerServing * multiplier,
                proteinGrams: recipe.proteinPerServing * multiplier,
                carbohydratesGrams: recipe.carbohydratesPerServing * multiplier,
                fatGrams: recipe.fatPerServing * multiplier,
                source: "recipe",
                externalFoodID: recipe.id.uuidString
            ))
            _ = PersistenceErrorReporter.save(modelContext, operation: "Rezept kochen abschließen")
        } else {
            saveScannedProducts()
        }
        dismiss()
    }

    private func bestIngredientMatch(for food: NutritionFood) -> RecipeIngredient? {
        let productTokens = meaningfulTokens(food.name)
        return ingredients
            .map { ingredient in
                (ingredient, meaningfulTokens(ingredient.name).intersection(productTokens).count)
            }
            .filter { $0.1 > 0 }
            .max { $0.1 < $1.1 }?.0
    }

    private func meaningfulTokens(_ value: String) -> Set<String> {
        let ignored: Set = ["und", "oder", "mit", "für", "im", "in", "der", "die", "das"]
        return Set(value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
            .filter { $0.count > 2 && !ignored.contains($0) })
    }

    private var scanMessagePresented: Binding<Bool> {
        Binding(get: { scanMessage != nil }, set: {
            if !$0 {
                scanMessage = nil
            }
        })
    }
}

private struct CustomStepTimerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onStart: (Int) -> Void
    @State private var minutes = "5"

    var body: some View {
        NavigationStack {
            Form {
                Section("Eigener Schritt-Timer") {
                    TextField("Minuten", text: $minutes)
                        .keyboardType(.numberPad)
                    Text("Der Timer gilt nur für den aktuell angezeigten Zubereitungsschritt.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Timer einstellen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Starten") {
                        let value = Int(minutes) ?? 0
                        guard value > 0 else { return }
                        onStart(value * 60)
                        dismiss()
                    }
                    .disabled((Int(minutes) ?? 0) <= 0)
                }
            }
        }
    }
}

private struct ScannedCookingProduct: Identifiable {
    let id = UUID()
    let food: NutritionFood
    var matchedIngredient: String
    var amountText = "100"
    var unit: String {
        food.unit
    }
}

private struct CookingCompletionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let defaultServings: Int
    let onComplete: (Double) -> Void
    @State private var portionsText: String

    init(defaultServings: Int, onComplete: @escaping (Double) -> Void) {
        self.defaultServings = defaultServings
        self.onComplete = onComplete
        _portionsText = State(initialValue: "1")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Kochen abschließen") {
                    Text("Wie viele Portionen hast du gegessen?")
                    TextField("Portionen", text: $portionsText)
                        .keyboardType(.decimalPad)
                    Text("Das Rezept ist für \(defaultServings) Portion(en) angelegt.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Fertig gekocht")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let portions = Double(portionsText.replacingOccurrences(of: ",", with: ".")) ?? 1
                        onComplete(max(portions, 0.1))
                        dismiss()
                    }
                }
            }
        }
    }
}
