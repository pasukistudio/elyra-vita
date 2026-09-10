import SwiftUI

struct NutritionFoodRow: View {
    let food: NutritionFood
    let accentColor: Color
    let isFavorite: Bool

    var body: some View {
        HStack {
            Image(systemName: "fork.knife")
                .foregroundStyle(accentColor)
                .frame(width: 28)
            Text(food.name)
                .foregroundStyle(.primary)
            Spacer()
            if isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("Favorit")
            }
            Text(food.caloriesPer100, format: .number.precision(.fractionLength(0)))
                .foregroundStyle(.secondary)
            Text("kcal/100")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
