import SwiftData
import SwiftUI

#Preview {
    AddNutritionEntryView(selectedDate: .now, accentColor: .orange)
        .modelContainer(for: [NutritionEntry.self, CustomFood.self, FavoriteFood.self], inMemory: true)
}
