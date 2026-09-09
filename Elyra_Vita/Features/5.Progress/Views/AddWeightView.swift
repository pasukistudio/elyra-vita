import SwiftUI
import SwiftData
import OSLog
import PasukiUI

// MARK: - AddWeightView

/// Erfasst eine Gewichtsmessung und zeigt die Messungen des ausgewählten Tages.
struct AddWeightView: View {

    // MARK: - Abhängigkeiten und Zustand

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \WeightEntry.date, order: .reverse)
    private var entries: [WeightEntry]

    @State private var weightText = ""
    @State private var editingEntry: WeightEntry?
    @State private var entryToDelete: WeightEntry?
    @State private var pendingReplacementWeight: Double?
    @State private var errorMessage: String?
    @FocusState private var weightFocused: Bool

    private let logger = Logger(
        subsystem: "de.pasukistudio.elyra-vita",
        category: "Weight"
    )

    let selectedDate: Date
    let accentColor: Color
    let entryToEdit: WeightEntry?

    // MARK: - Initialisierung

    init(selectedDate: Date, accentColor: Color, entryToEdit: WeightEntry? = nil) {
        self.selectedDate = selectedDate
        self.accentColor = accentColor
        self.entryToEdit = entryToEdit
        _editingEntry = State(initialValue: entryToEdit)
        _weightText = State(
            initialValue: entryToEdit?.weightKilograms.formatted(
                .number.locale(Locale(identifier: "de_DE"))
            ) ?? ""
        )
    }

    // MARK: - Ansicht

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    inputCard
                    dailyLogCard
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Gewicht erfassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
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
            } message: {
                Text("Diese Messung wird aus deinem Logbuch und aus der Synchronisierung entfernt.")
            }
            .confirmationDialog(
                "Gewicht ersetzen?",
                isPresented: Binding(
                    get: { pendingReplacementWeight != nil },
                    set: { isPresented in
                        if !isPresented { pendingReplacementWeight = nil }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button("Gewicht ersetzen") {
                    replaceExistingWeight()
                }
                Button("Abbrechen", role: .cancel) {
                    pendingReplacementWeight = nil
                }
            } message: {
                Text("Für diesen Tag gibt es bereits eine Messung. Soll sie durch den neuen Wert ersetzt werden?")
            }
            .alert(
                "Gewicht konnte nicht gespeichert werden",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { isPresented in
                        if !isPresented { errorMessage = nil }
                    }
                )
            ) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Unbekannter Fehler")
            }
        }
    }

    // MARK: - Eingabe

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(
                inputTitle,
                systemImage: "scalemass.fill"
            )
                .font(.headline)

            HStack(spacing: 12) {
                TextField("z. B. 72,5", text: $weightText)
                    .keyboardType(.decimalPad)
                    .focused($weightFocused)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(
                        Color(.tertiarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )

                Text("kg")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)

                Button {
                    saveWeight()
                } label: {
                    Image(systemName: editingEntry == nil ? "plus" : "checkmark")
                        .font(.headline.weight(.bold))
                        .frame(width: 48, height: 48)
                        .foregroundStyle(accentColor)
                        .background(
                            accentColor.opacity(0.10),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .disabled(parsedWeight == nil)
                .accessibilityLabel(
                    editingEntry == nil && entriesForSelectedDay.isEmpty
                        ? "Gewicht hinzufügen"
                        : "Gewicht speichern"
                )
            }

            if editingEntry != nil {
                Button("Bearbeitung abbrechen") {
                    editingEntry = nil
                    weightText = ""
                    weightFocused = false
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .appCard()
    }

    // MARK: - Tageslogbuch

    private var dailyLogCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Tageslogbuch", systemImage: "clock.fill")
                .font(.headline)

            if entriesForSelectedDay.isEmpty {
                Text("Für diesen Tag gibt es noch keine Messung.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entriesForSelectedDay) { entry in
                    HStack(spacing: 12) {
                        Image(systemName: "scalemass")
                            .foregroundStyle(accentColor)
                            .frame(width: 28)

                        Text(entry.weightKilograms, format: .number.precision(.fractionLength(1)))
                            .font(.body.weight(.medium))

                        Text("kg")
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(entry.date, format: .dateTime.hour().minute())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()

                        Button {
                            editingEntry = entry
                            weightText = entry.weightKilograms.formatted(
                                .number.locale(Locale(identifier: "de_DE"))
                            )
                            weightFocused = true
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundStyle(accentColor)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Gewichtseintrag bearbeiten")

                        Button {
                            entryToDelete = entry
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Gewichtseintrag löschen")
                    }
                    .padding(.vertical, 7)

                    if entry.id != entriesForSelectedDay.last?.id {
                        Divider()
                    }
                }
            }
        }
        .appCard()
    }

    // MARK: - Aktionen und Werte

    private var parsedWeight: Double? {
        let normalized = weightText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard let value = Double(normalized), value > 0 else { return nil }
        return value
    }

    private var entriesForSelectedDay: [WeightEntry] {
        entries.filter {
            Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
        }
    }

    private var inputTitle: String {
        // MARK: - Tagesregel sichtbar machen
        // Nach der ersten Messung wird keine zweite Messung angelegt,
        // sondern der bestehende Tageswert ersetzt.
        if editingEntry != nil { return "Messung bearbeiten" }
        if entriesForSelectedDay.isEmpty { return "Neue Messung" }
        return "Messung ersetzen"
    }

    private func saveWeight() {
        guard let parsedWeight else { return }

        if let editingEntry {
            editingEntry.update(weightKilograms: parsedWeight)
            do {
                try modelContext.save()
                self.editingEntry = nil
                weightText = ""
                weightFocused = false
            } catch {
                modelContext.rollback()
                logger.error("Gewicht konnte nicht aktualisiert werden: \(error.localizedDescription)")
                errorMessage = "Die Gewichtsmessung konnte nicht aktualisiert werden."
            }
            return
        }

        // MARK: - Eine Messung pro Kalendertag
        // Bestehende Daten bleiben erhalten, aber neue Eingaben für denselben
        // Tag aktualisieren den Tageswert statt einen zweiten Datensatz zu
        // erzeugen. Der ursprüngliche Messzeitpunkt bleibt dabei erhalten.
        if !entriesForSelectedDay.isEmpty {
            pendingReplacementWeight = parsedWeight
            return
        }

        let now = Date()
        let calendar = Calendar.current
        let entryDate = calendar.date(
            bySettingHour: calendar.component(.hour, from: now),
            minute: calendar.component(.minute, from: now),
            second: calendar.component(.second, from: now),
            of: selectedDate
        ) ?? selectedDate

        modelContext.insert(
            WeightEntry(date: entryDate, weightKilograms: parsedWeight)
        )

        do {
            try modelContext.save()
            weightText = ""
            weightFocused = false
        } catch {
            modelContext.rollback()
            logger.error("Gewicht konnte nicht gespeichert werden: \(error.localizedDescription)")
            errorMessage = "Die Gewichtsmessung konnte nicht gespeichert werden."
        }
    }

    private func replaceExistingWeight() {
        // MARK: - Ersetzung bestätigen
        guard let pendingReplacementWeight,
              let existingEntry = entriesForSelectedDay.first
        else { return }

        existingEntry.update(weightKilograms: pendingReplacementWeight)

        do {
            try modelContext.save()
            self.pendingReplacementWeight = nil
            weightText = ""
            weightFocused = false
        } catch {
            modelContext.rollback()
            logger.error("Gewicht konnte nicht ersetzt werden: \(error.localizedDescription)")
            self.pendingReplacementWeight = nil
            errorMessage = "Die Gewichtsmessung konnte nicht gespeichert werden."
        }
    }

    // MARK: - Löschen

    private func deleteSelectedEntry() {
        guard let entryToDelete else { return }

        modelContext.delete(entryToDelete)
        self.entryToDelete = nil

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            logger.error("Gewicht konnte nicht gelöscht werden: \(error.localizedDescription)")
            errorMessage = "Der Gewichtseintrag konnte nicht gelöscht werden."
        }
    }
}

#Preview("AddWeightView") {
    AddWeightView(selectedDate: .now, accentColor: .teal)
        .modelContainer(for: [WeightEntry.self], inMemory: true)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
}
