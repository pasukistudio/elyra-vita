import Charts
import PasukiUI
import SwiftData
import SwiftUI

// MARK: - ProgressView

/// Zeigt Gewichtstrend und Messlogbuch als Teil des täglichen Gesundheitsbilds.
struct ProgressView: View {
    // MARK: - Abhängigkeiten und Zustand

    @Environment(\.modelContext) var modelContext
    @Query(sort: \WeightEntry.date, order: .reverse)
    var entries: [WeightEntry]

    @State private var showingAddWeight = false
    @State private var entryToEdit: WeightEntry?
    @State private var entryToDelete: WeightEntry?
    @State var selectedChartDate: Date?
    @State var selectedRange: ChartRange = .month

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
        .sheet(
            isPresented: $showingAddWeight,
            onDismiss: { entryToEdit = nil },
            content: {
                AddWeightView(
                    selectedDate: entryToEdit?.date ?? .now,
                    accentColor: accentColor,
                    entryToEdit: entryToEdit
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        )
        .confirmationDialog(
            "Gewichtseintrag löschen?",
            isPresented: Binding(
                get: { entryToDelete != nil },
                set: { isPresented in
                    if !isPresented {
                        entryToDelete = nil
                    }
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
        PersistenceErrorReporter.save(modelContext, operation: "Gewichtseintrag löschen")
    }
}

// MARK: - ChartRange

enum ChartRange: String, CaseIterable, Identifiable {
    case week
    case month
    case quarter
    case year

    var id: Self {
        self
    }

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
