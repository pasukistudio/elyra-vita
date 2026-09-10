import PasukiUI
import SwiftData
import SwiftUI
import UserNotifications

// MARK: - ContentView

/// Zentrale Navigation der App mit gemeinsamer Tagesauswahl und Sheets.
struct ContentView: View {
    // MARK: - Abhängigkeiten

    @Environment(\.modelContext) private var modelContext

    // MARK: - Navigation und Auswahl

    /// Der aktuell aktive Tab.
    @State var selectedSection: AppSection = .overview

    /// Das Datum der gemeinsamen Datumsnavigation.
    @State var selectedDate = Date()

    /// Steuert die Präsentation der Datumsauswahl.
    @State var showingDatePicker = false

    /// Steuert die Präsentation der Ansicht zum Wasser hinzufügen.
    @State var showingAddWater = false

    /// Steuert die Präsentation der Ansicht zum Gewicht erfassen.
    @State var showingAddWeight = false

    /// Steuert die Präsentation der Ansicht zum Ernährungseintrag.
    @State var showingAddNutrition = false

    /// Mahlzeitentyp, der aus dem Toolbar-Menü vorgewählt wurde.
    @State var selectedNutritionMealType: NutritionMealType = .snack

    /// Gespeicherte Einstellungen, automatisch von SwiftData beobachtet.
    @Query var userSettings: [UserSettings]

    /// Steuert die Navigation zur SettingsView.
    @State var showingSettings = false

    /// Steuert das Anlegen einer Einkaufsliste aus der Planning-Toolbar.
    @State private var showingNewShoppingList = false

    /// Steuert das Anlegen einer To-do-Liste aus der Planning-Toolbar.
    @State private var showingNewTodoList = false
    @State private var showingNewHabit = false
    @State private var selectedPlanningArea: PlanningArea = .habits
    @State private var persistenceErrorMessage: String?
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Habit.updatedAt, order: .reverse) private var habits: [Habit]
    @Query private var habitCompletions: [HabitCompletion]

    /// Steuert die Navigation zu einem einzelnen Gesundheitstrend.
    @State private var selectedHealthMetric: HealthTrendMetric?
    @State private var selectedHealthMetricDate = Date()

    // MARK: - Ansicht

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedSection) {
                overview
                nutrition
                planning
                recipes
            }
            .toolbar {
                sharedToolbar
            }
            .toolbar(
                selectedSection == .overview || selectedSection == .nutrition
                    ? .visible
                    : .hidden,
                for: .navigationBar
            )
            .navigationBarTitleDisplayMode(.inline)
            .tint(selectedAccentColor)
            .environment(\.elyraAccentColor, selectedAccentColor)
            .preferredColorScheme(preferredColorScheme)
            .navigationDestination(isPresented: $showingSettings) {
                SettingsView()
            }
            .navigationDestination(item: $selectedHealthMetric) { metric in
                HealthTrendView(
                    metric: metric,
                    accentColor: selectedAccentColor,
                    referenceDate: selectedHealthMetricDate,
                    onAddWater: {
                        selectedDate = selectedHealthMetricDate
                        showingAddWater = true
                    }
                )
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerView(
                    selectedDate: $selectedDate
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingAddWater) {
                AddWaterView(
                    selectedDate: selectedDate,
                    accentColor: selectedAccentColor,
                    onAddWater: { amount in
                        addWater(amount, for: selectedDate)
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.regularMaterial)
            }
            .sheet(isPresented: $showingAddWeight) {
                AddWeightView(
                    selectedDate: selectedDate,
                    accentColor: selectedAccentColor
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.regularMaterial)
            }
            .sheet(isPresented: $showingAddNutrition) {
                AddNutritionEntryView(
                    selectedDate: selectedDate,
                    accentColor: selectedAccentColor,
                    initialMealType: selectedNutritionMealType
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(.systemBackground))
            }
            .appBackground()
        }
        .onReceive(NotificationCenter.default.publisher(for: .persistenceError)) { notification in
            persistenceErrorMessage = notification.object as? String
        }
        .alert("Änderung konnte nicht gespeichert werden", isPresented: persistenceErrorPresented) {
            Button("OK", role: .cancel) { persistenceErrorMessage = nil }
        } message: {
            Text(persistenceErrorMessage ?? "Bitte versuche es erneut.")
        }
        .task {
            await synchronizeHabitNotifications()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await synchronizeHabitNotifications() }
            }
        }
    }

    private var persistenceErrorPresented: Binding<Bool> {
        Binding(
            get: { persistenceErrorMessage != nil },
            set: {
                if !$0 {
                    persistenceErrorMessage = nil
                }
            }
        )
    }

    private func synchronizeHabitNotifications() async {
        _ = await HabitNotificationService.synchronize(habits: habits, completions: habitCompletions)
    }

    // MARK: - Tab-Bereiche

    /// Der Uebersichts-Tab.
    private var overview: some View {
        OverviewView(
            selectedDate: selectedDate,
            calorieGoal: userSettings.first?.calorieGoal ?? 1800,
            waterGoal: userSettings.first?.waterGoalML ?? 2500,
            accentColor: selectedAccentColor,
            onOpenWaterTrend: {
                selectedHealthMetric = .water
                selectedHealthMetricDate = selectedDate
            },
            onOpenHealthMetric: { metric in
                selectedHealthMetric = metric
                selectedHealthMetricDate = selectedDate
            }
        )
        .tabItem {
            Label(
                AppSection.overview.title,
                systemImage: AppSection.overview.icon
            )
        }
        .tag(AppSection.overview)
    }

    /// Der Ernaehrungs-Tab.
    private var nutrition: some View {
        NutritionView(
            selectedDate: selectedDate,
            calorieGoal: userSettings.first?.calorieGoal ?? 1800,
            accentColor: selectedAccentColor
        )
        .tabItem {
            Label(
                AppSection.nutrition.title,
                systemImage: AppSection.nutrition.icon
            )
        }
        .tag(AppSection.nutrition)
    }

    /// Der Planungs-Tab.
    private var planning: some View {
        PlanningView(
            selectedArea: $selectedPlanningArea,
            showingNewList: $showingNewShoppingList,
            showingNewTodoList: $showingNewTodoList,
            showingNewHabit: $showingNewHabit
        )
        .tabItem {
            Label(
                AppSection.planning.title,
                systemImage: AppSection.planning.icon
            )
        }
        .tag(AppSection.planning)
    }

    /// Der Rezept-Tab.
    private var recipes: some View {
        RecipesView()
            .tabItem {
                Label(
                    AppSection.recipes.title,
                    systemImage: AppSection.recipes.icon
                )
            }
            .tag(AppSection.recipes)
    }

    // MARK: - Datumsnavigation

    /// Zeigt fuer bekannte Tage einen kurzen Namen an.
    var dateTitle: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(selectedDate) {
            return "Heute"
        }

        if calendar.isDateInTomorrow(selectedDate) {
            return "Morgen"
        }

        if calendar.isDateInYesterday(selectedDate) {
            return "Gestern"
        }

        return selectedDate.formatted(
            .dateTime
                .day()
                .month(.wide)
                .year()
        )
    }

    /// Verschiebt das ausgewaehlte Datum um eine Anzahl von Tagen.
    /// Negative Werte gehen zurueck, positive Werte gehen voraus.
    func moveSelectedDate(by days: Int) {
        guard let newDate = Calendar.current.date(
            byAdding: .day,
            value: days,
            to: selectedDate
        ) else {
            return
        }

        selectedDate = newDate
    }

    // MARK: - Wasser speichern

    /// Speichert den Eintrag am ausgewählten Tag mit der aktuellen Uhrzeit.
    private func addWater(_ amount: Int, for day: Date) {
        guard amount > 0 else {
            return
        }

        let now = Date()
        let calendar = Calendar.current
        let entryDate = calendar.date(
            bySettingHour: calendar.component(.hour, from: now),
            minute: calendar.component(.minute, from: now),
            second: calendar.component(.second, from: now),
            of: day
        ) ?? day

        modelContext.insert(WaterEntry(date: entryDate, amount: amount))

        PersistenceErrorReporter.save(modelContext, operation: "Wassereintrag speichern")
    }
}
