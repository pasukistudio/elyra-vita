import Charts
import PasukiUI
import SwiftData
import SwiftUI

/// Zeigt den Verlauf eines einzelnen Gesundheitswerts.
struct HealthTrendView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.scenePhase) var scenePhase

    @Query(sort: \WaterEntry.date, order: .forward)
    var waterEntries: [WaterEntry]
    @Query(sort: \WeightEntry.date, order: .forward)
    var weightEntries: [WeightEntry]
    @Query(sort: \NutritionEntry.date, order: .forward)
    var nutritionEntries: [NutritionEntry]

    @State var selectedRange: HealthTrendRange = .week
    @State var points: [HealthTrendPoint] = []
    @State var isLoading = false
    @State var errorMessage: String?
    @State var editingWaterEntry: WaterEntry?
    @State var editingWeightEntry: WeightEntry?
    @State var deletingWaterEntry: WaterEntry?
    @State var deletingWeightEntry: WeightEntry?

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
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await loadPoints() }
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
                set: {
                    if !$0 {
                        errorMessage = nil
                    }
                }
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
                set: {
                    if !$0 {
                        deletingWaterEntry = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Eintrag löschen", role: .destructive) { deleteWaterEntry() }
            Button("Abbrechen", role: .cancel) { deletingWaterEntry = nil }
        }
        .confirmationDialog(
            "Gewichtseintrag löschen?",
            isPresented: Binding(
                get: { deletingWeightEntry != nil },
                set: {
                    if !$0 {
                        deletingWeightEntry = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Eintrag löschen", role: .destructive) { deleteWeightEntry() }
            Button("Abbrechen", role: .cancel) { deletingWeightEntry = nil }
        }
        .sheet(item: $editingWaterEntry) { entry in
            AddWaterView(selectedDate: entry.date, accentColor: accentColor, entryToEdit: entry)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingWeightEntry) { entry in
            AddWeightView(selectedDate: entry.date, accentColor: accentColor, entryToEdit: entry)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}
