import SwiftUI

struct CalorieSummaryCard: View {
    // MARK: - Eingaben

    /// Die aktuell gegessenen Kalorien.
    /// Der Platzhalter wird später durch echte Tagesdaten ersetzt.
    let consumedCalories: Int

    /// Das persönliche Tagesziel.
    /// Der Standardwert dient zunächst nur als Vorschauwert.
    let calorieGoal: Int

    /// Die in den Einstellungen ausgewählte Akzentfarbe.
    let accentColor: Color

    // MARK: - Initialisierung

    init(
        consumedCalories: Int = 0,
        calorieGoal: Int = 1_800,
        accentColor: Color
    ) {
        self.consumedCalories = max(0, consumedCalories)
        self.calorieGoal = max(0, calorieGoal)
        self.accentColor = accentColor
    }

    // MARK: - Berechnete Werte

    /// Verbleibende Kalorien bis zum Tagesziel.
    private var remainingCalories: Int {
        max(calorieGoal - consumedCalories, 0)
    }

    /// Der Wert, der rechts in der Karte angezeigt wird.
    private var displayedStatusValue: Int {
        hasExceededGoal
            ? consumedCalories - calorieGoal
            : remainingCalories
    }

    /// Fortschritt zwischen 0 und 1 für den ProgressView.
    private var calorieProgress: Double {
        guard calorieGoal > 0 else {
            return 0
        }

        return min(
            max(Double(consumedCalories) / Double(calorieGoal), 0),
            1
        )
    }

    /// Gibt an, ob das Tagesziel überschritten wurde.
    private var hasExceededGoal: Bool {
        consumedCalories > calorieGoal
    }

    /// Die Farbe für den verbleibenden Wert und den Fortschrittsbalken.
    private var statusColor: Color {
        hasExceededGoal ? .red : accentColor
    }

    // MARK: - Ansicht

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            calorieValues
            calorieProgressView
            calorieGoalView

            if hasExceededGoal {
                exceededGoalView
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .stroke(
                .primary.opacity(0.07),
                lineWidth: 1
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Kalorien: \(consumedCalories) gegessen, "
                + "\(displayedStatusValue) "
                + "\(hasExceededGoal ? "darüber" : "übrig"), "
                + "Tagesziel \(calorieGoal)"
        )
    }

    // MARK: - Karteninhalt

    /// Zeigt die beiden wichtigsten Tageswerte nebeneinander an.
    private var calorieValues: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Gegessen")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(consumedCalories) kcal")
                    .font(.title2.bold())
            }

            Spacer(minLength: 16)

            VStack(alignment: .trailing, spacing: 12) {
                Text(hasExceededGoal ? "Darüber" : "Übrig")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(displayedStatusValue) kcal")
                    .font(.title2.bold())
                    .foregroundStyle(statusColor)
            }
        }
    }

    /// Visualisiert, wie viel vom Tagesziel bereits verbraucht wurde.
    private var calorieProgressView: some View {
        SwiftUI.ProgressView(value: calorieProgress)
            .tint(statusColor)
    }

    /// Zeigt das Tagesziel und den aktuellen prozentualen Fortschritt an.
    private var calorieGoalView: some View {
        HStack {
            Text("Tagesziel: \(calorieGoal) kcal")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text("\(Int(calorieProgress * 100)) %")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    /// Macht eine Überschreitung des Tagesziels zusätzlich sichtbar.
    private var exceededGoalView: some View {
        Label(
            "Tagesziel überschritten",
            systemImage: "exclamationmark.triangle.fill"
        )
        .font(.caption)
        .foregroundStyle(.red)
    }
}

#Preview("CalorieSummaryCard") {
    VStack(spacing: 16) {
        CalorieSummaryCard(accentColor: .blue)

        CalorieSummaryCard(
            consumedCalories: 2_000,
            calorieGoal: 1_800,
            accentColor: .blue
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
