import SwiftUI
import SwiftData

struct ContentView: View {
    // MARK: - Navigation und Auswahl

    /// Der aktuell aktive Tab.
    @State private var selectedSection: AppSection = .overview

    /// Das Datum der gemeinsamen Datumsnavigation.
    @State private var selectedDate = Date()

    @State private var showingDatePicker = false

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
                onAdd: {},
                onSettings: {
                    showingSettings = true
                }
            )
        }
    }

    // MARK: - Tab-Bereiche

    /// Der Uebersichts-Tab.
    private var overview: some View {
        OverviewView(accentColor: selectedAccentColor)
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

    /// Der Fortschritts-Tab.
    private var progress: some View {
        ProgressView()
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
        ) ?? .blue

        switch accentColor {
        case .custom:
            return Color(
                hexString: settings.customAccentHex
            )

        default:
            return accentColor.color
                ?? ColorPreset.blue.color
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [
                UserSettings.self
            ],
            inMemory: true
        )
}
