import SwiftUI

extension HealthTrendView {
    @ViewBuilder
    var logbookContent: some View {
        switch metric {
        case .water:
            if waterLogEntries.isEmpty {
                emptyLogbookMessage
            } else {
                ForEach(waterLogEntries) { entry in
                    logbookRow(
                        value: Double(entry.amount),
                        unit: "ml",
                        date: entry.date,
                        onEdit: { editingWaterEntry = entry },
                        onDelete: { deletingWaterEntry = entry }
                    )
                }
            }
        case .weight:
            if weightLogEntries.isEmpty {
                emptyLogbookMessage
            } else {
                ForEach(weightLogEntries) { entry in
                    logbookRow(
                        value: entry.weightKilograms,
                        unit: "kg",
                        date: entry.date,
                        onEdit: { editingWeightEntry = entry },
                        onDelete: { deletingWeightEntry = entry }
                    )
                }
            }
        default:
            if points.isEmpty {
                emptyLogbookMessage
            } else {
                ForEach(points.reversed()) { point in
                    HStack {
                        Text(point.value, format: .number.precision(.fractionLength(1)))
                            .font(.body.weight(.medium))
                        Text(metric.unit).foregroundStyle(.secondary)
                        Spacer()
                        Text(point.date, format: .dateTime.day().month().year())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var emptyLogbookMessage: some View {
        Text("Für diesen Zeitraum gibt es noch keine Daten.")
            .foregroundStyle(.secondary)
    }

    private var waterLogEntries: [WaterEntry] {
        waterEntries
            .filter { $0.date >= rangeStart && $0.date < rangeEnd }
            .sorted { $0.date > $1.date }
    }

    private var weightLogEntries: [WeightEntry] {
        weightEntries
            .filter { $0.date >= rangeStart && $0.date < rangeEnd }
            .sorted { $0.date > $1.date }
    }

    private func logbookRow(
        value: Double,
        unit: String,
        date: Date,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(value, format: .number.precision(.fractionLength(1)))
                .font(.body.weight(.medium))
            Text(unit).foregroundStyle(.secondary)
            Spacer()
            Text(date, format: .dateTime.day().month().year())
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Menu {
                Button("Bearbeiten", systemImage: "pencil", action: onEdit)
                Button("Löschen", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(accentColor)
                    .frame(width: 32, height: 32)
            }
            .menuStyle(.borderlessButton)
            .accessibilityLabel("Weitere Aktionen")
        }
    }
}
