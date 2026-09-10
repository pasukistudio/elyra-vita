import SwiftData
import SwiftUI

#Preview("NutritionView") {
    NutritionView(accentColor: .orange)
        .modelContainer(
            for: [NutritionEntry.self, CustomFood.self, FavoriteFood.self],
            inMemory: true
        )
}
