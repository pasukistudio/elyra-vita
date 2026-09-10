import PasukiUI
import SwiftData
import SwiftUI

struct RecipesView: View {
    @Environment(\.elyraAccentColor) private var accentColor
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Recipe.updatedAt, order: .reverse) private var recipes: [Recipe]
    @Query var ingredients: [RecipeIngredient]
    @Query var steps: [RecipeStep]
    @Query(sort: \RecipeBook.createdAt) private var recipeBooks: [RecipeBook]
    @Query var memberships: [RecipeBookMembership]
    @State private var showingEditor = false
    @State private var showingFilterSheet = false
    @State private var showingBooksSheet = false
    @State private var editingRecipe: Recipe?
    @State var deletingRecipe: Recipe?
    @State private var ingredientFilter = ""
    @State private var matchAllIngredients = false
    @State private var maximumMinutes: Int?
    @State private var searchText = ""
    @State private var sortOption: RecipeSort = .recent

    private var filteredRecipes: [Recipe] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = query.isEmpty ? recipes : recipes.filter { recipe in
            recipe.title.localizedCaseInsensitiveContains(query) ||
                ingredients
                .filter { $0.recipeID == recipe.id }
                .contains { $0.name.localizedCaseInsensitiveContains(query) }
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
        let terms = ingredientFilter
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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
                                    RecipeDetailView(
                                        recipe: recipe,
                                        ingredients: ingredients.filter { $0.recipeID == recipe.id },
                                        steps: steps.filter { $0.recipeID == recipe.id }
                                    )
                                } label: {
                                    RecipeCardView(recipe: recipe)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(
                                        "Favorit umschalten",
                                        systemImage: recipe.isFavorite ? "heart.slash" : "heart"
                                    ) { toggleFavorite(recipe) }
                                    Button("Bearbeiten", systemImage: "pencil") { editingRecipe = recipe }
                                    Button(
                                        "Löschen",
                                        systemImage: "trash",
                                        role: .destructive
                                    ) { deletingRecipe = recipe }
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
            RecipeEditorView(
                recipe: recipe,
                ingredients: ingredients.filter { $0.recipeID == recipe.id },
                steps: steps.filter { $0.recipeID == recipe.id }
            )
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
}
