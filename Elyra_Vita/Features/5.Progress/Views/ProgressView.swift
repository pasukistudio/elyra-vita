import SwiftUI
import SwiftData
import Charts
import PasukiUI

// MARK: - ProgressView

/// Zeigt Gewichtstrend und Messlogbuch als Teil des täglichen Gesundheitsbilds.
struct ProgressView: View {

    // MARK: - Abhängigkeiten und Zustand

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.date, order: .reverse)
    private var entries: [WeightEntry]

    @State private var showingAddWeight = false
    @State private var entryToEdit: WeightEntry?
    @State private var entryToDelete: WeightEntry?
    @State private var selectedChartDate: Date?
    @State private var selectedRange: ChartRange = .month

    let accentColor: Color
    let onOpenTrend: (HealthTrendMetric) -> Void

    init(
        accentColor: Color = .blue,
        onOpenTrend: @escaping (HealthTrendMetric) -> Void = { _ in }
    ) {
        self.accentColor = accentColor
        self.onOpenTrend = onOpenTrend
    }
    // MARK: - Ansicht

    var body: some View {
        List {
            Section("Trends") {
                ForEach(HealthTrendMetric.allCases.filter { $0 != .weight }) { metric in
                    Button {
                        onOpenTrend(metric)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: metric.systemImage)
                                .foregroundStyle(metric.color)
                                .frame(width: 28)

                            Text(metric.title)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Trend anzeigen")
                }
            }

            Section("Gewicht") {
                summaryCard
            }

            Section("Verlauf") {
                weightChart
            }

            Section("Logbuch") {
                if entries.isEmpty {
                    Text("Noch keine Gewichtsmessungen vorhanden.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entries) { entry in
                        HStack {
                            Text(entry.weightKilograms, format: .number.precision(.fractionLength(1)))
                                .font(.body.weight(.medium))
                            Text("kg")
                                .foregroundStyle(.secondary)
                            Spacer()
                            HStack(spacing: 0) {
                                Text(entry.date, format: .dateTime.day().month().year())
                                Text(" um ")
                                Text(entry.date, format: .dateTime.hour().minute())
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                            Button {
                                startEditing(entry)
                            } label: {
                                Image(systemName: "pencil")
                                    .foregroundStyle(accentColor)
                                    .frame(width: 32, height: 32)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Gewichtseintrag bearbeiten")
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                entryToDelete = entry
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .appBackground()
        .navigationTitle("Gesundheit")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    entryToEdit = nil
                    showingAddWeight = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Gewicht erfassen")
            }
        }
        .sheet(isPresented: $showingAddWeight, onDismiss: {
            entryToEdit = nil
        }) {
            AddWeightView(
                selectedDate: entryToEdit?.date ?? .now,
                accentColor: accentColor,
                entryToEdit: entryToEdit
            )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "Gewichtseintrag löschen?",
            isPresented: Binding(
                get: { entryToDelete != nil },
                set: { isPresented in
                    if !isPresented { entryToDelete = nil }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Eintrag löschen", role: .destructive) {
                deleteSelectedEntry()
            }
            Button("Abbrechen", role: .cancel) {
                entryToDelete = nil
            }
        }
    }

    // MARK: - Zusammenfassung

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let latest = entries.first {
                // MARK: - Aktuelles Gewicht
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

    // MARK: - Gewichtsdiagramm

    private var weightChart: some View {
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
                    // MARK: - Eindeutige Datumsmarkierungen
                    // Swift Charts erzeugt mit `.automatic` teilweise mehrere
                    // Marken für denselben Kalendertag. Wir verwenden deshalb
                    // direkt die Messzeitpunkte eines Tages als Achsenwerte.
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

    private var chartEntries: [WeightEntry] {
        let startDate = Calendar.current.date(
            byAdding: .day,
            value: -selectedRange.days,
            to: .now
        ) ?? .now

        return entries
            .filter { $0.date >= startDate }
            .sorted { $0.date < $1.date }
    }

    private var chartAxisDates: [Date] {
        // MARK: - Achsenwerte aus Messdaten ableiten
        // Pro Kalendertag wird nur der erste Messzeitpunkt als X-Achsenwert
        // verwendet. Dadurch bleibt jede Datumsbeschriftung eindeutig und
        // liegt direkt unter dem dazugehörigen Punkt im Diagramm.
        var seenDays = Set<Date>()

        return chartEntries.compactMap { entry in
            let day = Calendar.current.startOfDay(for: entry.date)
            guard seenDays.insert(day).inserted else { return nil }
            return entry.date
        }
    }

    private var chartYDomain: ClosedRange<Double> {
        guard let minimum = chartEntries.map(\.weightKilograms).min(),
              let maximum = chartEntries.map(\.weightKilograms).max()
        else {
            return 0...100
        }

        let padding = max(0.5, (maximum - minimum) * 0.15)
        return (minimum - padding)...(maximum + padding)
    }

    private var selectedEntry: WeightEntry? {
        guard let selectedChartDate else { return nil }

        return chartEntries.min {
            abs($0.date.timeIntervalSince(selectedChartDate))
                < abs($1.date.timeIntervalSince(selectedChartDate))
        }
    }

    // MARK: - Löschen

    private func startEditing(_ entry: WeightEntry) {
        // MARK: - Logbuch bearbeiten
        entryToEdit = entry
        showingAddWeight = true
    }

    private func deleteSelectedEntry() {
        guard let entryToDelete else { return }
        modelContext.delete(entryToDelete)
        self.entryToDelete = nil
        try? modelContext.save()
    }
}

// MARK: - ChartRange

private enum ChartRange: String, CaseIterable, Identifiable {
    case week
    case month
    case quarter
    case year

    var id: Self { self }

    var days: Int {
        switch self {
        case .week: 7
        case .month: 30
        case .quarter: 90
        case .year: 365
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .week: "Woche"
        case .month: "Monat"
        case .quarter: "3 Monate"
        case .year: "Jahr"
        }
    }
}
