import PasukiUI
import SwiftData
import SwiftUI

struct RecipeBookDetailView: View {
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
                ContentUnavailableView(
                    "Noch keine Rezepte",
                    systemImage: "book",
                    description: Text("Füge Rezepte über den Rezepteditor zu diesem Buch hinzu.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(bookRecipes) { recipe in
                            NavigationLink {
                                RecipeDetailView(
                                    recipe: recipe,
                                    ingredients: ingredients.filter { $0.recipeID == recipe.id },
                                    steps: steps.filter { $0.recipeID == recipe.id }
                                )
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
                Text(recipe.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                HStack(spacing: 12) {
                    Label("\(recipe.servings)", systemImage: "person.2")
                    if recipe.prepMinutes > 0 {
                        Label("\(recipe.prepMinutes) Min.", systemImage: "clock")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.quaternary)
                .frame(height: 1)
                .padding(.leading, 82)
        }
    }
}
