import SwiftData
import SwiftUI

#Preview("HealthTrendView") {
    NavigationStack {
        HealthTrendView(metric: .steps, accentColor: .blue)
    }
    .modelContainer(for: [WaterEntry.self, WeightEntry.self, NutritionEntry.self], inMemory: true)
}
