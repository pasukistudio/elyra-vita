import SwiftUI

extension ProgressView {
    var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let latest = entries.first {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(latest.weightKilograms, format: .number.precision(.fractionLength(1)))
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(accentColor)

                    Text("kg")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text("letzte Messung")
                    .foregroundStyle(.secondary)

                if entries.count > 1, let previous = entries.dropFirst().first {
                    let difference = latest.weightKilograms - previous.weightKilograms
                    Text(
                        difference == 0
                            ? "Keine Veränderung zur vorherigen Messung"
                            : "\(difference > 0 ? "+" : "")\(difference, specifier: "%.1f") kg zur vorherigen Messung"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            } else {
                Text("Noch kein Gewicht erfasst")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
