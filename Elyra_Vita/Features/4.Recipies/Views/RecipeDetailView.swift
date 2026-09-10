import PasukiUI
import SwiftData
import SwiftUI

struct RecipeDetailView: View {
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
                .frame(height: 230)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                if !recipe.note.isEmpty {
                    Text(recipe.note)
                        .font(.body)
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

                HStack {
                    Label("\(recipe.servings) Portionen", systemImage: "person.2")
                    Spacer()
                    if recipe.prepMinutes > 0 {
                        Label("\(recipe.prepMinutes) Min.", systemImage: "clock")
                    }
                }
                .foregroundStyle(accentColor)
                .padding(18)
                .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

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
                        Text(
                            "\(recipe.caloriesPerServing.formatted(.number.precision(.fractionLength(0 ... 0)))) "
                                + "kcal / Portion"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                detailSection("Zutaten") {
                    ForEach(ingredients.sorted { $0.position < $1.position }) { ingredient in
                        Text(
                            [ingredient.amount, ingredient.unit, ingredient.name]
                                .filter { !$0.isEmpty }
                                .joined(separator: " ")
                        )
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
                    .foregroundStyle(accentColor)
                    .padding(.top, 8)
                }

                detailSection("Zubereitung") {
                    ForEach(steps.sorted { $0.position < $1.position }) { step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(step.position + 1)")
                                .font(.headline)
                                .frame(width: 30, height: 30)
                                .background(.gray.opacity(0.2), in: Circle())
                            Text(step.instruction)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
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
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 0, content: content)
                .padding(18)
                .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var placeholder: some View {
        Image(systemName: "fork.knife")
            .font(.largeTitle)
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.orange.opacity(0.12))
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
            let unit = ingredient.unit.isEmpty ? "Stück" : ingredient.unit
            let amount = Double(ingredient.amount.replacingOccurrences(of: ",", with: ".")) ?? 1
            if let existing = try? modelContext.fetch(FetchDescriptor<ShoppingListItem>()).first(where: {
                $0.listID == list.id && $0.name.caseInsensitiveCompare(name) == .orderedSame && $0.unit == unit
            }) {
                existing.update(quantity: existing.quantity + amount)
            } else {
                modelContext.insert(ShoppingListItem(listID: list.id, name: name, quantity: amount, unit: unit))
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
