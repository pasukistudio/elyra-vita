import SwiftUI
import SwiftData
import Charts
import PasukiUI

// MARK: - HealthTrendView

/// Zeigt den Verlauf eines einzelnen Gesundheitswerts.
///
/// Apple-Health-Werte bleiben read-only und werden direkt aus HealthKit
/// geladen. Wasser und Gewicht stammen aus SwiftData und behalten deshalb
/// zusätzlich ihre fachlichen Logbuchdaten.
struct HealthTrendView: View {

    // MARK: - Abhängigkeiten und Zustand

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \WaterEntry.date, order: .forward)
    private var waterEntries: [WaterEntry]

    @Query(sort: \WeightEntry.date, order: .forward)
    private var weightEntries: [WeightEntry]

    @Query(sort: \NutritionEntry.date, order: .forward)
    private var nutritionEntries: [NutritionEntry]

    @State private var selectedRange: HealthTrendRange = .week
    @State private var points: [HealthTrendPoint] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var editingWaterEntry: WaterEntry?
    @State private var editingWeightEntry: WeightEntry?
    @State private var deletingWaterEntry: WaterEntry?
    @State private var deletingWeightEntry: WeightEntry?

    let metric: HealthTrendMetric
    let accentColor: Color
    let referenceDate: Date
    let onAddWater: () -> Void

    init(
        metric: HealthTrendMetric,
        accentColor: Color,
        referenceDate: Date = .now,
        onAddWater: @escaping () -> Void = {}
    ) {
        self.metric = metric
        self.accentColor = accentColor
        self.referenceDate = referenceDate
        self.onAddWater = onAddWater
    }

    // MARK: - Ansicht

    var body: some View {
        List {
            Section("Verlauf") {
                Picker("Zeitraum", selection: $selectedRange) {
                    ForEach(HealthTrendRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                trendChart
            }

            Section("Logbuch") {
                logbookContent
            }
        }
        .appBackground()
        .navigationTitle(metric.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if metric == .water {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onAddWater) {
                        Label("Wasser hinzufügen", systemImage: "plus")
                    }
                    .accessibilityLabel("Wasser hinzufügen")
                }
            }
        }
        .task(id: selectedRange) {
            await loadPoints()
        }
        .overlay {
            if isLoading {
                SwiftUI.ProgressView("Daten werden geladen …")
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .alert(
            "Trend konnte nicht geladen werden",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unbekannter Fehler")
        }
        .confirmationDialog(
            "Wassereintrag löschen?",
            isPresented: Binding(
                get: { deletingWaterEntry != nil },
                set: { if !$0 { deletingWaterEntry = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Eintrag löschen", role: .destructive) {
                deleteWaterEntry()
            }
            Button("Abbrechen", role: .cancel) { deletingWaterEntry = nil }
        }
        .confirmationDialog(
            "Gewichtseintrag löschen?",
            isPresented: Binding(
                get: { deletingWeightEntry != nil },
                set: { if !$0 { deletingWeightEntry = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Eintrag löschen", role: .destructive) {
                deleteWeightEntry()
            }
            Button("Abbrechen", role: .cancel) { deletingWeightEntry = nil }
        }
        .sheet(item: $editingWaterEntry) { entry in
            AddWaterView(
                selectedDate: entry.date,
                accentColor: accentColor,
                entryToEdit: entry
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingWeightEntry) { entry in
            AddWeightView(
                selectedDate: entry.date,
                accentColor: accentColor,
                entryToEdit: entry
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Logbuch

    @ViewBuilder
    private var logbookContent: some View {
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

    // MARK: - Lokale Einträge löschen

    private func deleteWaterEntry() {
        guard let deletingWaterEntry else { return }
        modelContext.delete(deletingWaterEntry)
        self.deletingWaterEntry = nil
        saveLocalChanges(errorMessage: "Der Wassereintrag konnte nicht gelöscht werden.")
    }

    private func deleteWeightEntry() {
        guard let deletingWeightEntry else { return }
        modelContext.delete(deletingWeightEntry)
        self.deletingWeightEntry = nil
        saveLocalChanges(errorMessage: "Der Gewichtseintrag konnte nicht gelöscht werden.")
    }

    private func saveLocalChanges(errorMessage: String) {
        do {
            try modelContext.save()
        } catch {
            self.errorMessage = errorMessage
        }
    }

    // MARK: - Diagramm

    /// Liefert die fachlich aggregierten Punkte für die sichtbare Kurve.
    ///
    /// Die Rohdaten bleiben in `points` erhalten und werden nur für die
    /// Darstellung in passende Zeit-Buckets zusammengefasst.
    private var chartPoints: [HealthTrendPoint] {
        guard !points.isEmpty else { return [] }

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: points) { point in
            chartBucketStart(for: point.date, calendar: calendar)
        }

        return grouped.keys.sorted().compactMap { bucketDate in
            guard let bucketPoints = grouped[bucketDate], !bucketPoints.isEmpty else {
                return nil
            }

            let value: Double
            if metric == .weight {
                // Für Gewicht ist die letzte Messung des Buckets fachlich
                // aussagekräftiger als ein künstlicher Durchschnittswert.
                value = bucketPoints.max { $0.date < $1.date }?.value ?? 0
            } else {
                // Aktivitäts-, Ernährungs- und Wasserdaten werden als
                // Tagesdurchschnitt des jeweiligen Zeit-Buckets dargestellt.
                value = bucketPoints.map(\.value).reduce(0, +) /
                    Double(bucketPoints.count)
            }

            return HealthTrendPoint(date: bucketDate, value: value)
        }
    }

    /// Bestimmt das sichtbare Zeitintervall abhängig vom gewählten Zeitraum.
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

    /// Wählt nur die Achsenpositionen aus. Die Kurve selbst bleibt vollständig.
    private var chartAxisPoints: [HealthTrendPoint] {
        let maximumPoints = 7

        guard points.count > maximumPoints else {
            return points
        }

        let lastIndex = points.count - 1
        return (0..<maximumPoints).map { pointIndex in
            let relativePosition = Double(pointIndex) / Double(maximumPoints - 1)
            let sourceIndex = Int((relativePosition * Double(lastIndex)).rounded())
            return points[sourceIndex]
        }
    }

    /// Die beiden Randpunkte bleiben bewusst ohne Datumslabel.
    private var chartLabelPoints: [HealthTrendPoint] {
        guard chartAxisPoints.count > 2 else {
            return []
        }

        return Array(chartAxisPoints.dropFirst().dropLast())
    }

    @ViewBuilder
    private var trendChart: some View {
        if chartPoints.isEmpty && !isLoading {
            ContentUnavailableView(
                "Keine Daten",
                systemImage: "chart.xyaxis.line",
                description: Text("Für diesen Zeitraum wurden keine Werte gefunden.")
            )
            .frame(maxWidth: .infinity, minHeight: 190)
        } else if chartPoints.isEmpty {
            SwiftUI.ProgressView()
                .frame(maxWidth: .infinity, minHeight: 190)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Chart(chartPoints) { point in
                    LineMark(
                        x: .value("Datum", point.date),
                        y: .value(metric.unit, point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(accentColor)

                    PointMark(
                        x: .value("Datum", point.date),
                        y: .value(metric.unit, point.value)
                    )
                    .foregroundStyle(accentColor)
                }
                .chartXScale(
                    domain: chartPoints[0].date...chartPoints[chartPoints.count - 1].date
                )
                .chartYAxis {
                    // Der Richtwert fünf führt bei Charts automatischer Skalierung
                    // in diesem Verlauf zu vier gut lesbaren Referenzwerten.
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 5)) {
                        AxisGridLine()
                            .foregroundStyle(.secondary.opacity(0.2))
                        AxisValueLabel()
                    }
                }
                .chartXAxis {
                    AxisMarks(values: chartAxisPoints.map(\.date)) { _ in
                        AxisGridLine()
                            .foregroundStyle(.secondary.opacity(0.2))
                    }
                }
                .chartPlotStyle { plotArea in
                    // Der Plot endet oberhalb der Datumslabels. Dadurch liegen die
                    // Labels nicht auf der unteren Null-Linie des Diagramms.
                    plotArea.padding(.bottom, 22)
                }
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

    // MARK: - Diagrammformatierung

    /// Formatiert kurze Diagramm-Datumslabels unabhängig von der
    /// systemabhängigen Darstellung mit deutschem Punkttrenner.
    private func chartDateLabel(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.day, .month], from: date)
        let day = components.day ?? 0
        let month = components.month ?? 0
        return String(format: "%02d.%02d", day, month)
    }

    /// Erklärt die zeitliche Zusammenfassung direkt unter dem Diagramm.
    private var aggregationHint: String {
        switch selectedRange {
        case .week:
            return metric == .weight
                ? "Tageswerte · Gewicht: letzte Messung des Tages"
                : "Tageswerte"
        case .month:
            return metric == .weight
                ? "2-Tages-Intervalle · Gewicht: letzte Messung des Intervalls"
                : "Durchschnitt je 2-Tages-Intervall"
        case .threeMonths:
            return metric == .weight
                ? "Wochenwerte · Gewicht: letzte Messung der Woche"
                : "Durchschnitt je Woche"
        case .year:
            return metric == .weight
                ? "Monatswerte · Gewicht: letzte Messung des Monats"
                : "Durchschnitt je Monat"
        }
    }

    // MARK: - Datenaufbereitung

    private var rangeStart: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        return calendar.date(
            byAdding: .day,
            value: -(selectedRange.days - 1),
            to: today
        ) ?? today
    }

    private var rangeEnd: Date {
        let calendar = Calendar.current
        return calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: referenceDate)
        ) ?? referenceDate
    }

    @MainActor
    private func loadPoints() async {
        isLoading = true
        defer { isLoading = false }

        if metric.usesHealthKit {
            await loadHealthKitPoints()
        } else {
            points = localPoints()
        }
    }

    @MainActor
    private func loadHealthKitPoints() async {
        guard !HealthKitService.isDisabledForCurrentProcess else {
            points = []
            return
        }

        do {
            let service = HealthKitService.shared
            try await service.requestAuthorization()

            let calendar = Calendar.current
            var dates: [Date] = []
            var date = rangeStart

            while date < rangeEnd {
                dates.append(date)
                date = calendar.date(
                    byAdding: .day,
                    value: 1,
                    to: date
                ) ?? rangeEnd
            }

            let metricsByDate = try await service.dailyMetrics(
                from: rangeStart,
                to: rangeEnd
            )

            var loadedPoints: [HealthTrendPoint] = []
            for date in dates {
                guard let metrics = metricsByDate[calendar.startOfDay(for: date)] else {
                    continue
                }
                if let value = value(for: metric, in: metrics) {
                    loadedPoints.append(HealthTrendPoint(date: date, value: value))
                }
            }

            points = loadedPoints
            errorMessage = nil
        } catch {
            points = []
            errorMessage = error.localizedDescription
        }
    }

    private func localPoints() -> [HealthTrendPoint] {
        let calendar = Calendar.current

        switch metric {
        case .calories:
            let grouped = Dictionary(grouping: nutritionEntries.filter {
                $0.date >= rangeStart && $0.date < rangeEnd
            }) {
                calendar.startOfDay(for: $0.date)
            }

            return grouped.keys.sorted().map { date in
                HealthTrendPoint(
                    date: date,
                    value: grouped[date, default: []].reduce(0) { $0 + $1.calories }
                )
            }

        case .water:
            let grouped = Dictionary(grouping: waterEntries.filter {
                $0.date >= rangeStart && $0.date < rangeEnd
            }) {
                calendar.startOfDay(for: $0.date)
            }

            return grouped.keys.sorted().map { date in
                HealthTrendPoint(
                    date: date,
                    value: Double(grouped[date, default: []].reduce(0) { $0 + $1.amount })
                )
            }

        case .weight:
            return weightEntries
                .filter { $0.date >= rangeStart && $0.date < rangeEnd }
                .map { HealthTrendPoint(date: $0.date, value: $0.weightKilograms) }

        default:
            return []
        }
    }

    private func value(for metric: HealthTrendMetric, in metrics: HealthMetrics) -> Double? {
        switch metric {
        case .calories: nil
        case .steps: metrics.steps
        case .walkingRunningDistance: metrics.walkingRunningDistanceKilometers
        case .activeEnergy: metrics.activeEnergyKilocalories
        case .basalEnergy: metrics.basalEnergyKilocalories
        case .totalEnergy: metrics.totalEnergyKilocalories
        case .protein: metrics.proteinGrams
        case .carbohydrates: metrics.carbohydratesGrams
        case .fat: metrics.fatGrams
        case .weight, .water: nil
        }
    }
}

// MARK: - Vorschau

#Preview("HealthTrendView") {
    NavigationStack {
        HealthTrendView(metric: .steps, accentColor: .blue)
    }
    .modelContainer(for: [WaterEntry.self, WeightEntry.self, NutritionEntry.self], inMemory: true)
}
