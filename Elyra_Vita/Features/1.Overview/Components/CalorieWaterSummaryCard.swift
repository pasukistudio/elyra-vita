import SwiftUI
import PasukiUI

/// Zeigt die beiden wichtigsten Tagesziele kompakt in einer gemeinsamen Karte.
///
/// Die Karte bündelt Kalorien und Wasser, damit die Übersichtsseite auf einem
/// iPhone-Bildschirm kurz und schnell erfassbar bleibt.
struct CalorieWaterSummaryCard: View {

    // MARK: - Eingaben

    /// Aktuell gegessene Kalorien.
    let consumedCalories: Int

    /// Persönliches Kalorienziel.
    let calorieGoal: Int

    /// Aktuell getrunkenes Wasser in Millilitern.
    let consumedWater: Int

    /// Persönliches Wasserziel in Millilitern.
    let waterGoal: Int

    /// Gibt an, ob ein Kalorienziel aktiv ist.
    let hasCalorieGoal: Bool

    /// Gibt an, ob ein Wasserziel aktiv ist.
    let hasWaterGoal: Bool

    /// Die in den Einstellungen ausgewählte Akzentfarbe.
    let accentColor: Color

    /// Öffnet den Wasser-Trend mit Diagramm und Logbuch.
    let onWaterTrendTap: () -> Void

    /// Öffnet den Kalorien-Trend mit Diagramm und Logbuch.
    let onCalorieTrendTap: () -> Void

    // MARK: - Initialisierung

    init(
        consumedCalories: Int = 0,
        calorieGoal: Int = 1_800,
        consumedWater: Int = 0,
        waterGoal: Int = 2_500,
        hasCalorieGoal: Bool = true,
        hasWaterGoal: Bool = true,
        accentColor: Color,
        onWaterTrendTap: @escaping () -> Void = {},
        onCalorieTrendTap: @escaping () -> Void = {}
    ) {
        self.consumedCalories = max(0, consumedCalories)
        self.calorieGoal = max(0, calorieGoal)
        self.consumedWater = max(0, consumedWater)
        self.waterGoal = max(0, waterGoal)
        self.hasCalorieGoal = hasCalorieGoal
        self.hasWaterGoal = hasWaterGoal
        self.accentColor = accentColor
        self.onWaterTrendTap = onWaterTrendTap
        self.onCalorieTrendTap = onCalorieTrendTap
    }

    // MARK: - Berechnete Werte

    /// Ermittelt den Kalorienfortschritt zwischen 0 und 1.
    private var calorieProgress: Double {
        guard hasCalorieGoal, calorieGoal > 0 else { return 0 }
        return min(Double(consumedCalories) / Double(calorieGoal), 1)
    }

    /// Ermittelt den Wasserfortschritt zwischen 0 und 1.
    private var waterProgress: Double {
        guard hasWaterGoal, waterGoal > 0 else { return 0 }
        return min(Double(consumedWater) / Double(waterGoal), 1)
    }

    // MARK: - Ansicht

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            calorieColumn

            Divider()

            waterColumn
        }
        .appCard()
    }

    // MARK: - Zielspalten

    /// Linke Spalte für das Kalorienziel.
    private var calorieColumn: some View {
        Button(action: onCalorieTrendTap) {
            goalColumn(
                title: "Kalorien",
                icon: "flame.fill",
                iconColor: .orange,
                value: "\(consumedCalories) kcal",
                goalText: hasCalorieGoal ? "von \(calorieGoal) kcal" : "Kein Ziel festgelegt",
                progress: calorieProgress,
                progressColor: consumedCalories > calorieGoal ? .red : .orange,
                percentage: Int(calorieProgress * 100)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    /// Rechte Spalte für das Wasserziel.
    private var waterColumn: some View {
        Button(action: onWaterTrendTap) {
            goalColumn(
                title: "Wasser",
                icon: "drop.fill",
                iconColor: .blue,
                value: "\(consumedWater) ml",
                goalText: hasWaterGoal ? "von \(waterGoal) ml" : "Kein Ziel festgelegt",
                progress: waterProgress,
                progressColor: consumedWater > waterGoal ? .red : .blue,
                percentage: Int(waterProgress * 100)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    /// Baut eine einheitliche Zielspalte für Kalorien und Wasser auf.
    private func goalColumn(
        title: String,
        icon: String,
        iconColor: Color,
        value: String,
        goalText: String,
        progress: Double,
        progressColor: Color,
        percentage: Int
    ) -> some View {
    VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 48, height: 48)
                .background(iconColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline .weight(.semibold))

                Text(value)
                    .font(.headline .weight(.bold))
                    .foregroundStyle(progressColor)

                Text(goalText)
                    .font(.caption .weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }

            AppProgressBar(
                progress: progress,
                color: progressColor
            )

            Text("\(percentage) %")
            .font(.headline .weight(.bold))
                .foregroundStyle(progressColor)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Vorschauen

#Preview("Ziele – Standard") {
    CalorieWaterSummaryCard(
        consumedCalories: 0,
        calorieGoal: 1_800,
        consumedWater: 0,
        waterGoal: 2_500,
        hasCalorieGoal: true,
        hasWaterGoal: true,
        accentColor: .teal
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Ziele – Fortschritt") {
    CalorieWaterSummaryCard(
        consumedCalories: 900,
        calorieGoal: 1_800,
        consumedWater: 1_250,
        waterGoal: 2_500,
        hasCalorieGoal: true,
        hasWaterGoal: true,
        accentColor: .teal
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Ziele – Erreicht") {
    CalorieWaterSummaryCard(
        consumedCalories: 1_800,
        calorieGoal: 1_800,
        consumedWater: 2_500,
        waterGoal: 2_500,
        hasCalorieGoal: true,
        hasWaterGoal: true,
        accentColor: .teal
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Ziele – Überschritten") {
    CalorieWaterSummaryCard(
        consumedCalories: 2_000,
        calorieGoal: 1_800,
        consumedWater: 3_000,
        waterGoal: 2_500,
        hasCalorieGoal: true,
        hasWaterGoal: true,
        accentColor: .teal
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Ziele – Kalorienziel fehlt") {
    CalorieWaterSummaryCard(
        consumedCalories: 450,
        calorieGoal: 0,
        consumedWater: 1_000,
        waterGoal: 2_500,
        hasCalorieGoal: false,
        hasWaterGoal: true,
        accentColor: .teal
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Ziele – Wasserziel fehlt") {
    CalorieWaterSummaryCard(
        consumedCalories: 900,
        calorieGoal: 1_800,
        consumedWater: 750,
        waterGoal: 0,
        hasCalorieGoal: true,
        hasWaterGoal: false,
        accentColor: .teal
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Ziele – Keine Ziele") {
    CalorieWaterSummaryCard(
        consumedCalories: 450,
        calorieGoal: 0,
        consumedWater: 750,
        waterGoal: 0,
        hasCalorieGoal: false,
        hasWaterGoal: false,
        accentColor: .teal
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
