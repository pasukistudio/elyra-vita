import PasukiUI
import SwiftData
import SwiftUI

#Preview {
    let proAccess = PasukiStoreKitProService(
        configuration: PasukiProProductConfiguration(
            featureByProductIdentifier: [:]
        )
    )
    let syncMonitor = PasukiCloudKitSyncMonitor(isEnabled: false)

    ContentView()
        .modelContainer(
            for: [
                UserSettings.self,
                WaterEntry.self,
                WeightEntry.self,
                NutritionEntry.self,
                CustomFood.self,
                FavoriteFood.self,
                ShoppingList.self,
                ShoppingListItem.self,
                ShoppingListItemHistory.self,
                TodoList.self,
                TodoTask.self,
                Habit.self,
                HabitCompletion.self,
            ],
            inMemory: true
        )
        .environmentObject(proAccess)
        .environmentObject(syncMonitor)
}
