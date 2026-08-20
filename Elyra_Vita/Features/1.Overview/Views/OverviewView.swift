import SwiftUI


struct OverviewView: View {

    // MARK: - Ansicht
    let accentColor: Color

    var body: some View {
        List {
            // MARK: - Tagesziele

            /// Kalorien und Wasser werden kompakt in einer gemeinsamen Karte angezeigt.
            Section {
                CalorieWaterSummaryCard(accentColor: accentColor)
                .listRowInsets(EdgeInsets())
            } header: {
                Text("Tagesziele")
            }

            // MARK: - Tageswerte

            /// Die Tageswertekarte bildet den zweiten Abschnitt der Übersicht.
            Section {
                DailyMetricsSummaryCard(
                    accentColor: accentColor
                )
                .listRowInsets(EdgeInsets())
            } header: {
                HStack {
                    Text("Tageswerte")

                    Spacer()

                    Text("Health · jetzt")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            accentColor.opacity(0.12),
                            in: Capsule()
                        )
                }
            }

        }
        .listStyle(.insetGrouped)
    }

}

// MARK: - Preview
#Preview("OverviewView") {
    OverviewView(accentColor: .blue)
}
