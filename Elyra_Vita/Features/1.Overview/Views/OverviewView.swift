import SwiftUI
import SwiftData

// MARK: - OverviewView

/// Zeigt Tagesziele, Gesundheitswerte und den aktuellen Wasserverbrauch an.
struct OverviewView: View {

    // MARK: - Daten

    /// Das Datum, für das die Übersicht den Wasserverbrauch zeigt.
    let selectedDate: Date

    @Query(sort: \WaterEntry.date, order: .forward)
    private var waterEntries: [WaterEntry]

    @Query(sort: \NutritionEntry.date, order: .forward)
    private var nutritionEntries: [NutritionEntry]

    @State private var healthMetrics: HealthMetrics?
    @State private var healthErrorMessage: String?

    // MARK: - Eingaben

    let accentColor: Color
    let calorieGoal: Int
    let waterGoal: Int
    let onOpenWaterTrend: () -> Void
    let onOpenHealthMetric: (HealthTrendMetric) -> Void

    init(
        selectedDate: Date = .now,
        calorieGoal: Int = 1_800,
        waterGoal: Int = 2_500,
        accentColor: Color,
        onOpenWaterTrend: @escaping () -> Void = {},
        onOpenHealthMetric: @escaping (HealthTrendMetric) -> Void = { _ in }
    ) {
        self.selectedDate = selectedDate
        self.calorieGoal = calorieGoal
        self.waterGoal = waterGoal
        self.accentColor = accentColor
        self.onOpenWaterTrend = onOpenWaterTrend
        self.onOpenHealthMetric = onOpenHealthMetric
    }

    // MARK: - Berechnete Werte

    private var consumedWater: Int {
        waterEntries
            .filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
            .reduce(0) { $0 + $1.amount }
    }

    /// Summiert die gespeicherten Ernährungseinträge des ausgewählten Tages.
    private var consumedCalories: Int {
        Int(dayNutritionEntries.reduce(0) { $0 + $1.calories }.rounded())
    }

    /// Liefert nur die Ernährungseinträge des aktuell ausgewählten Tages.
    /// Dadurch bleiben Kalorien und Makronährstoffe immer synchron.
    private var dayNutritionEntries: [NutritionEntry] {
        nutritionEntries.filter {
            Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
        }
    }

    /// Summiert einen Nährwert des Tages. Ohne Einträge bleibt der Wert nil,
    /// damit die Übersicht „– g“ statt eines irreführenden Nullwerts zeigt.
    private func nutritionTotal(
        _ keyPath: KeyPath<NutritionEntry, Double>
    ) -> Double? {
        guard !dayNutritionEntries.isEmpty else { return nil }
        return dayNutritionEntries.reduce(0) { $0 + $1[keyPath: keyPath] }
    }

    var body: some View {
        List {
            // MARK: - Tagesziele

            /// Kalorien und Wasser werden kompakt in einer gemeinsamen Karte angezeigt.
            Section {
                CalorieWaterSummaryCard(
                    consumedCalories: consumedCalories,
                    calorieGoal: calorieGoal,
                    consumedWater: consumedWater,
                    waterGoal: waterGoal,
                    accentColor: accentColor,
                    onWaterTrendTap: onOpenWaterTrend
                )
                .listRowInsets(EdgeInsets())
            } header: {
                Text("Tagesziele")
            }

            // MARK: - Tageswerte

            /// Die Tageswertekarte bildet den zweiten Abschnitt der Übersicht.
            Section {
                DailyMetricsSummaryCard(
                    accentColor: accentColor,
                    healthMetrics: healthMetrics,
                    nutritionProteinGrams: nutritionTotal(\.proteinGrams),
                    nutritionCarbohydratesGrams: nutritionTotal(\.carbohydratesGrams),
                    nutritionFatGrams: nutritionTotal(\.fatGrams),
                    onMetricTap: onOpenHealthMetric
                )
                .listRowInsets(EdgeInsets())
            } header: {
                HStack {
                    Text("Tageswerte")

                    Spacer()

                    Text(healthStatusText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            accentColor.opacity(0.12),
                            in: Capsule()
                        )
                }
            } footer: {
                if let healthErrorMessage {
                    Text("Apple Health: \(healthErrorMessage)")
                } else if healthMetrics?.containsData == false {
                    Text("Für diesen Tag wurden in Apple Health keine passenden Daten gefunden.")
                }
            }

        }
        .listStyle(.insetGrouped)
        .task(id: selectedDate) {
            await loadHealthMetrics()
        }
    }

    // MARK: - Apple Health

    private var healthStatusText: String {
        if healthMetrics?.containsData == true {
            return "Health · geladen"
        }

        if healthErrorMessage != nil {
            return "Health · Fehler"
        }

        if healthMetrics != nil {
            return "Health · keine Daten"
        }

        return "Health · wird geladen"
    }

    @MainActor
    private func loadHealthMetrics() async {
        healthMetrics = nil
        healthErrorMessage = nil

        guard !HealthKitService.isDisabledForCurrentProcess else {
            return
        }

        do {
            let service = HealthKitService.shared
            try await service.requestAuthorization()
            healthMetrics = try await service.metrics(for: selectedDate)
        } catch {
            healthErrorMessage = error.localizedDescription
        }
    }

}



// MARK: - Preview
#Preview("OverviewView") {
OverviewView(accentColor: .blue)
        .modelContainer(
            for: [WaterEntry.self, NutritionEntry.self],
            inMemory: true
        )
}
