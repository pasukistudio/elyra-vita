import Charts
import SwiftData
import SwiftUI

extension HealthTrendView {
    func deleteWaterEntry() {
        guard let deletingWaterEntry else { return }
        modelContext.delete(deletingWaterEntry)
        self.deletingWaterEntry = nil
        saveLocalChanges(errorMessage: "Der Wassereintrag konnte nicht gelöscht werden.")
    }

    func deleteWeightEntry() {
        guard let deletingWeightEntry else { return }
        modelContext.delete(deletingWeightEntry)
        self.deletingWeightEntry = nil
        saveLocalChanges(errorMessage: "Der Gewichtseintrag konnte nicht gelöscht werden.")
    }

    private func saveLocalChanges(errorMessage: String) {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            self.errorMessage = errorMessage
        }
    }

    private var chartPoints: [HealthTrendPoint] {
        guard !points.isEmpty else { return [] }
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: points) {
            chartBucketStart(for: $0.date, calendar: calendar)
        }

        return grouped.keys.sorted().compactMap { bucketDate in
            guard let bucketPoints = grouped[bucketDate], !bucketPoints.isEmpty else { return nil }
            let value: Double
            if metric == .weight {
                value = bucketPoints.max { $0.date < $1.date }?.value ?? 0
            } else {
                value = bucketPoints.map(\.value).reduce(0, +) / Double(bucketPoints.count)
            }
            return HealthTrendPoint(date: bucketDate, value: value)
        }
    }

    private func chartBucketStart(for date: Date, calendar: Calendar) -> Date {
        switch selectedRange {
        case .week:
            return calendar.startOfDay(for: date)
        case .month:
            let start = calendar.startOfDay(for: rangeStart)
            let current = calendar.startOfDay(for: date)
            let dayOffset = calendar.dateComponents([.day], from: start, to: current).day ?? 0
            let bucketOffset = (dayOffset / 2) * 2
            return calendar.date(byAdding: .day, value: bucketOffset, to: start) ?? start
        case .threeMonths:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        case .year:
            return calendar.dateInterval(of: .month, for: date)?.start ?? date
        }
    }

    private var chartAxisPoints: [HealthTrendPoint] {
        let maximumPoints = 7
        guard points.count > maximumPoints else { return points }
        let lastIndex = points.count - 1
        return (0 ..< maximumPoints).map { index in
            let position = Double(index) / Double(maximumPoints - 1)
            return points[Int((position * Double(lastIndex)).rounded())]
        }
    }

    private var chartLabelPoints: [HealthTrendPoint] {
        guard chartAxisPoints.count > 2 else { return [] }
        return Array(chartAxisPoints.dropFirst().dropLast())
    }

    @ViewBuilder
    var trendChart: some View {
        if chartPoints.isEmpty && !isLoading {
            ContentUnavailableView(
                "Keine Daten",
                systemImage: "chart.xyaxis.line",
                description: Text("Für diesen Zeitraum wurden keine Werte gefunden.")
            )
            .frame(maxWidth: .infinity, minHeight: 190)
        } else if chartPoints.isEmpty {
            SwiftUI.ProgressView().frame(maxWidth: .infinity, minHeight: 190)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Chart(chartPoints) { point in
                    LineMark(x: .value("Datum", point.date), y: .value(metric.unit, point.value))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(accentColor)
                    PointMark(x: .value("Datum", point.date), y: .value(metric.unit, point.value))
                        .foregroundStyle(accentColor)
                }
                .chartXScale(domain: chartPoints[0].date ... chartPoints[chartPoints.count - 1].date)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 5)) {
                        AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
                        AxisValueLabel()
                    }
                }
                .chartXAxis {
                    AxisMarks(values: chartAxisPoints.map(\.date)) { _ in
                        AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
                    }
                }
                .chartPlotStyle { $0.padding(.bottom, 22) }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        if let plotFrame = proxy.plotFrame {
                            let frame = geometry[plotFrame]
                            ForEach(chartLabelPoints) { point in
                                if let xPosition = proxy.position(forX: point.date) {
                                    Text(chartDateLabel(for: point.date))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .fixedSize()
                                        .position(
                                            x: frame.minX + xPosition,
                                            y: geometry.size.height - 12
                                        )
                                }
                            }
                        }
                    }
                }
                .frame(height: 230)
                Text(aggregationHint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func chartDateLabel(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.day, .month], from: date)
        return String(format: "%02d.%02d", components.day ?? 0, components.month ?? 0)
    }

    private var aggregationHint: String {
        switch selectedRange {
        case .week:
            metric == .weight ? "Tageswerte · Gewicht: letzte Messung des Tages" : "Tageswerte"
        case .month:
            metric == .weight
                ? "2-Tages-Intervalle · Gewicht: letzte Messung des Intervalls"
                : "Durchschnitt je 2-Tages-Intervall"
        case .threeMonths:
            metric == .weight ? "Wochenwerte · Gewicht: letzte Messung der Woche" : "Durchschnitt je Woche"
        case .year:
            metric == .weight ? "Monatswerte · Gewicht: letzte Messung des Monats" : "Durchschnitt je Monat"
        }
    }
}
