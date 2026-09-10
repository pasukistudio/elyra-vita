import SwiftUI

struct RecipeCardView: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 14) {
            recipeImage
            VStack(alignment: .leading, spacing: 7) {
                Text(recipe.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                if !recipe.category.isEmpty {
                    Text(recipe.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 14) {
                    Label("\(recipe.servings)", systemImage: "person.2")
                    if recipe.prepMinutes > 0 {
                        Label("\(recipe.prepMinutes) Min.", systemImage: "clock")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.quaternary)
                .frame(height: 1)
                .padding(.leading, 102)
        }
    }

    @ViewBuilder
    private var recipeImage: some View {
        if let url = URL(string: recipe.imageURL), !recipe.imageURL.isEmpty {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    placeholderImage
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            placeholderImage
                .frame(width: 88, height: 88)
        }
    }

    private var placeholderImage: some View {
        Image(systemName: "fork.knife")
            .font(.title2)
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.orange.opacity(0.12))
    }
}
