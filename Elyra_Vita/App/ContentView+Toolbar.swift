import PasukiUI
import SwiftUI

extension ContentView {
    /// Die Toolbar wird je nach aktivem Tab angepasst.
    @ToolbarContentBuilder
    var sharedToolbar: some ToolbarContent {
        SharedToolbar(
            title: dateTitle,
            onPrevious: { moveSelectedDate(by: -1) },
            onSelectDate: { showingDatePicker = true },
            onNext: { moveSelectedDate(by: 1) },
            menuActions: selectedSection == .overview
                ? SharedToolbarAction.overview
                : SharedToolbarAction.nutrition,
            onMenuAction: { action in
                handleToolbarAction(action)
            },
            onSettings: { showingSettings = true },
            isVisible: selectedSection == .overview || selectedSection == .nutrition
        )
    }

    /// Führt die Aktionen der gemeinsamen Toolbar aus.
    func handleToolbarAction(_ action: SharedToolbarAction) {
        switch action {
        case .water:
            showingAddWater = true
        case .weight:
            showingAddWeight = true
        case .meal, .snack:
            selectedNutritionMealType = .snack
            showingAddNutrition = true
        case .breakfast:
            selectedNutritionMealType = .breakfast
            showingAddNutrition = true
        case .lunch:
            selectedNutritionMealType = .lunch
            showingAddNutrition = true
        case .dinner:
            selectedNutritionMealType = .dinner
            showingAddNutrition = true
        }
    }
}
