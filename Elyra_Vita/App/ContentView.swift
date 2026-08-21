import SwiftUI
import SwiftData
import OSLog
import PasukiUI

// MARK: - ContentView

/// Zentrale Navigation der App mit gemeinsamer Tagesauswahl und Sheets.
struct ContentView: View {
    // MARK: - Abhängigkeiten

    @Environment(\.modelContext) private var modelContext

    private let logger = Logger(
        subsystem: "de.pasukistudio.elyra-vita",
        category: "Water"
    )

    // MARK: - Navigation und Auswahl

    /// Der aktuell aktive Tab.
    @State private var selectedSection: AppSection = .overview

    /// Das Datum der gemeinsamen Datumsnavigation.
    @State private var selectedDate = Date()

    /// Steuert die Präsentation der Datumsauswahl.
    @State private var showingDatePicker = false

    /// Steuert die Präsentation der Ansicht zum Wasser hinzufügen.
    @State private var showingAddWater = false

    /// Steuert die Präsentation der Ansicht zum Gewicht erfassen.
    @State private var showingAddWeight = false

    /// Gespeicherte Einstellungen, automatisch von SwiftData beobachtet.
    @Query private var userSettings: [UserSettings]

    /// Steuert die Navigation zur SettingsView.
    @State private var showingSettings = false

    // MARK: - Ansicht
    var body: some View {
        NavigationStack {
            ZStack {
                TabView(selection: $selectedSection) {
                    overview
                    nutrition
                    planning
                    recipies
                    progress
                }
            }
            .toolbar {
                sharedToolbar
            }
            .navigationBarTitleDisplayMode(.inline)
            .tint(selectedAccentColor)
            .preferredColorScheme(preferredColorScheme)
            .navigationDestination(isPresented: $showingSettings) {
                SettingsView()
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
            .appBackground()
        }
    }

    // MARK: - Gemeinsame Toolbar

    /// Die Toolbar gilt nur fuer Uebersicht und Ernaehrung.
    @ToolbarContentBuilder
    private var sharedToolbar: some ToolbarContent {
        if selectedSection == .overview ||
            selectedSection == .nutrition {
            SharedToolbar(
                title: dateTitle,
                onPrevious: {
                    moveSelectedDate(by: -1)
                },
                onSelectDate: {
                    showingDatePicker = true
                },
                onNext: {
                    moveSelectedDate(by: 1)
                },
                menuActions: selectedSection == .overview
                    ? SharedToolbarAction.overview
                    : SharedToolbarAction.nutrition,
                onMenuAction: { action in
                    handleToolbarAction(action)
                },
                onSettings: {
                    showingSettings = true
                }
            )
        }
    }

    // MARK: - Toolbar-Aktionen

    /// Führt die bereits implementierten Aktionen direkt aus und hält
    /// zukünftige Mahlzeit-/Gewicht-Views als klar benannte Fälle bereit.
    private func handleToolbarAction(_ action: SharedToolbarAction) {
        switch action {
        case .water:
            showingAddWater = true
        case .weight:
            showingAddWeight = true
        case .meal, .breakfast, .lunch, .dinner, .snack:
            // Die jeweiligen Erfassungs-Views folgen in den passenden Features.
            break
        }
    }

    // MARK: - Tab-Bereiche

    /// Der Uebersichts-Tab.
    private var overview: some View {
        OverviewView(
            selectedDate: selectedDate,
            calorieGoal: userSettings.first?.calorieGoal ?? 1_800,
            waterGoal: userSettings.first?.waterGoalML ?? 2_500,
            accentColor: selectedAccentColor,
            onOpenWater: {
                showingAddWater = true
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
        NutritionView()
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
        PlanningView()
            .tabItem {
                Label(
                    AppSection.planning.title,
                    systemImage: AppSection.planning.icon
                )
            }
            .tag(AppSection.planning)
    }

    /// Der Rezept-Tab.
    private var recipies: some View {
        RecipiesView()
            .tabItem {
                Label(
                    AppSection.recipies.title,
                    systemImage: AppSection.recipies.icon
                )
            }
            .tag(AppSection.recipies)
    }

    /// Der Gesundheits-Tab.
    private var progress: some View {
        ProgressView(accentColor: selectedAccentColor)
            .tabItem {
                Label(
                    AppSection.progress.title,
                    systemImage: AppSection.progress.icon
                )
            }
            .tag(AppSection.progress)
    }

    // MARK: - Datumsnavigation

    /// Zeigt fuer bekannte Tage einen kurzen Namen an.
    private var dateTitle: String {
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
    private func moveSelectedDate(by days: Int) {
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

        do {
            try modelContext.save()
        } catch {
            logger.error("Wassereintrag konnte nicht gespeichert werden: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Erscheinungsbild

    /// Uebersetzt die gespeicherte Auswahl in ein SwiftUI-Farbschema.
    private var preferredColorScheme: ColorScheme? {
        guard
            let rawValue =
                userSettings.first?.appearanceRawValue,
            let appearance =
                AppAppearance(rawValue: rawValue)
        else {
            return nil
        }

        return appearance.colorScheme
    }

    // MARK: - Akzentfarbe

    /// Ermittelt die Preset- oder eigene Akzentfarbe des Profils.
    private var selectedAccentColor: Color {
        guard let settings = userSettings.first else {
            return ColorPreset.blue.color
        }

        let accentColor = AppAccentColor(
            rawValue: settings.accentColorRawValue
        )

        if accentColor == .custom {
            return Color(
                hexString: settings.customAccentHex
            )
        }

        return accentColor.color ?? ColorPreset.blue.color
    }
}

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
                WeightEntry.self
            ],
            inMemory: true
        )
        .environmentObject(proAccess)
        .environmentObject(syncMonitor)
}
