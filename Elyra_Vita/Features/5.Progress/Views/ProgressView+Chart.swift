import Charts
import SwiftUI

extension ProgressView {
    var weightChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Zeitraum", selection: $selectedRange) {
                ForEach(ChartRange.allCases) { range in
                    Text(range.title).tag(range)
                }
            }
            .pickerStyle(.segmented)

            if chartEntries.isEmpty {
                ContentUnavailableView(
                    "Keine Messungen",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Für diesen Zeitraum gibt es noch keine Gewichtsdaten.")
                )
                .frame(maxWidth: .infinity, minHeight: 190)
            } else {
                Chart(chartEntries) { entry in
                    LineMark(
                        x: .value("Datum", entry.date),
                        y: .value("Gewicht", entry.weightKilograms)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(accentColor)

                    PointMark(
                        x: .value("Datum", entry.date),
                        y: .value("Gewicht", entry.weightKilograms)
                    )
                    .foregroundStyle(accentColor)
                }
                .chartYScale(domain: chartYDomain)
                .chartXAxis {
                    AxisMarks(values: chartAxisDates) { _ in
                        AxisGridLine()
                            .foregroundStyle(.secondary.opacity(0.2))
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                            .foregroundStyle(.secondary.opacity(0.2))
                        AxisValueLabel {
                            if let weight = value.as(Double.self) {
                                Text("\(weight, specifier: "%.1f")")
                            }
                        }
                    }
                }
                .chartXSelection(value: $selectedChartDate)
                .frame(height: 230)

                if let selectedEntry {
                    HStack {
                        Text(selectedEntry.date, format: .dateTime.day().month().year())
                        Spacer()
                        Text(
                            selectedEntry.weightKilograms,
                            format: .number.precision(.fractionLength(1))
                        )
                        .fontWeight(.semibold)
                        Text("kg")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    var chartEntries: [WeightEntry] {
        let startDate = Calendar.current.date(byAdding: .day, value: -selectedRange.days, to: .now) ?? .now
        return entries.filter { $0.date >= startDate }.sorted { $0.date < $1.date }
    }

    var chartAxisDates: [Date] {
        var seenDays = Set<Date>()
        return chartEntries.compactMap { entry in
            let day = Calendar.current.startOfDay(for: entry.date)
            guard seenDays.insert(day).inserted else { return nil }
            return entry.date
        }
    }

    var chartYDomain: ClosedRange<Double> {
        guard let minimum = chartEntries.map(\.weightKilograms).min(),
              let maximum = chartEntries.map(\.weightKilograms).max()
        else {
            return 0 ... 100
        }
        let padding = max(0.5, (maximum - minimum) * 0.15)
        return (minimum - padding) ... (maximum + padding)
    }

    var selectedEntry: WeightEntry? {
        guard let selectedChartDate else { return nil }
        return chartEntries.min {
            abs($0.date.timeIntervalSince(selectedChartDate))
                < abs($1.date.timeIntervalSince(selectedChartDate))
        }
    }
}
