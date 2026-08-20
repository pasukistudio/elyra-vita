import SwiftUI
import PasukiUI

/// Zeigt die wichtigsten Gesundheitswerte in einer gemeinsamen Karte an.
///
/// Die Karte ist bewusst als eigener Baustein aufgebaut, damit die
/// Tageswerte später unabhängig von der OverviewView erweitert werden können.
struct DailyMetricsSummaryCard: View {

    // MARK: - Eingaben

    /// Die aktuell ausgewählte Akzentfarbe der App.
    let accentColor: Color

    /// Die für den ausgewählten Tag aus Apple Health gelesenen Werte.
    let healthMetrics: HealthMetrics?

    init(
        accentColor: Color,
        healthMetrics: HealthMetrics? = nil
    ) {
        self.accentColor = accentColor
        self.healthMetrics = healthMetrics
    }

    // MARK: - Layout

    /// Jede Gesundheitszeile erhält dieselbe feste Höhe.
    /// Dadurch kann kein mehrzeiliger Platzhalter eine einzelne Zeile vergrößern.
    private static let metricRowHeight: CGFloat = 48

    // MARK: - Ansicht

    var body: some View {
        VStack(spacing: 0) {
            metricRow(
                title: "Schritte",
                value: integerText(healthMetrics?.steps, unit: "Schritte"),
                systemImage: "shoeprints.fill",
                color: .green
            )

            metricDivider

            metricRow(
                title: "Geh-/Laufdistanz",
                value: distanceText(healthMetrics?.walkingRunningDistanceKilometers),
                systemImage: "mappin.and.ellipse",
                color: .blue
            )

            metricDivider

            metricRow(
                title: "Aktiv verbrannt",
                value: integerText(healthMetrics?.activeEnergyKilocalories, unit: "kcal"),
                systemImage: "figure.run",
                color: .teal
            )

            metricDivider

            metricRow(
                title: "Ruheenergie",
                value: integerText(healthMetrics?.basalEnergyKilocalories, unit: "kcal"),
                systemImage: "figure.mind.and.body",
                color: .secondary
            )

            metricDivider

            metricRow(
                title: "Gesamtverbrauch",
                value: integerText(healthMetrics?.totalEnergyKilocalories, unit: "kcal"),
                systemImage: "bolt.fill",
                color: .orange
            )

            metricDivider

            metricRow(
                title: "Gewicht",
                value: weightText(healthMetrics?.weightKilograms),
                systemImage: "scalemass",
                color: .cyan
            )

            metricDivider

            macroRow
        }
        .appCard(
            padding: EdgeInsets(
                top: 8,
                leading: 20,
                bottom: 12,
                trailing: 20
            )
        )
    }

    // MARK: - Gesundheitszeile

    /// Baut eine einzelne Zeile mit Icon, Bezeichnung und Wert auf.
    private func metricRow(
        title: String,
        value: String,
        systemImage: String,
        color: Color
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(color)
                .frame(width: 28)

            Text(title)
                .font(.body)
                .lineLimit(1)

            Spacer(minLength: 10)

            Text(value)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.vertical, 10)
        .frame(height: Self.metricRowHeight)
    }

    /// Trennt die Gesundheitszeilen, ohne die Icon-Spalte zu durchschneiden.
    private var metricDivider: some View {
        Divider()
            .padding(.leading, 42)
    }

    // MARK: - Makronährstoffe

    /// Zeigt die drei Makronährstoffe in drei gleich breiten Spalten an.
    private var macroRow: some View {
        HStack(spacing: 0) {
            macroMetric(
                title: "Eiweiß",
                value: macroText(healthMetrics?.proteinGrams),
                percent: nil,
                color: .blue
            )

            Divider()

            macroMetric(
                title: "Kohlenhydrate",
                value: macroText(healthMetrics?.carbohydratesGrams),
                percent: nil,
                color: .teal
            )

            Divider()

            macroMetric(
                title: "Fett",
                value: macroText(healthMetrics?.fatGrams),
                percent: nil,
                color: .purple
            )
        }
        .padding(.top, 10)
        .frame(height: 70)
    }

    /// Baut eine einzelne Makronährstoff-Spalte auf.
    private func macroMetric(
        title: String,
        value: String,
        percent: String?,
        color: Color
    ) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(spacing: 5) {
                VStack(spacing: 1) {
                    Text(value)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(color)

                    if let percent {
                        Text(percent)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Formatierung

    private func integerText(_ value: Double?, unit: String) -> String {
        guard let value else { return "– \(unit)" }
        return "\(Int(value.rounded())) \(unit)"
    }

    private func distanceText(_ value: Double?) -> String {
        guard let value else { return "– km" }
        return "\(value.formatted(.number.precision(.fractionLength(1)))) km"
    }

    private func weightText(_ value: Double?) -> String {
        guard let value else { return "– kg" }
        return "\(value.formatted(.number.precision(.fractionLength(1)))) kg"
    }

    private func macroText(_ value: Double?) -> String {
        guard let value else { return "– g" }
        return "\(Int(value.rounded())) g"
    }
}

// MARK: - Vorschauen

#Preview("Tageswerte – Leerzustand") {
    DailyMetricsSummaryCard(accentColor: .teal)
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("Tageswerte – Dunkelmodus") {
    DailyMetricsSummaryCard(accentColor: .teal)
        .padding()
        .background(Color(.systemGroupedBackground))
        .preferredColorScheme(.dark)
}

#Preview("Tageswerte – Schmale Breite") {
    DailyMetricsSummaryCard(accentColor: .teal)
        .frame(width: 340)
        .padding()
        .background(Color(.systemGroupedBackground))
}
