import SwiftUI
import SwiftData
import OSLog
import PasukiUI

// MARK: - AddWaterView

/// Erfasst schnelle oder frei eingegebene Wasserportionen und zeigt das
/// Trinkprotokoll des ausgewählten Tages an.
struct AddWaterView: View {
    // MARK: - Umgebung und Eingaben

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var customAmountText = ""
    @State private var editingEntry: WaterEntry?
    @State private var entryToDelete: WaterEntry?
    @State private var deleteErrorMessage: String?
    @FocusState private var customAmountFocused: Bool

    private let logger = Logger(
        subsystem: "de.pasukistudio.elyra-vita",
        category: "WaterLog"
    )

    /// Das Datum, für das der Eintrag und das Logbuch gelten.
    let selectedDate: Date

    @Query(sort: \WaterEntry.date, order: .reverse)
    private var waterEntries: [WaterEntry]

    /// Akzentfarbe aus den App-Einstellungen.
    let accentColor: Color
    let entryToEdit: WaterEntry?

    /// Übergibt eine Menge an die spätere HealthKit-/SwiftData-Anbindung.
    let onAddWater: (Int) -> Void

    /// Häufige Portionsgrößen, die ohne Tastatureingabe hinzugefügt werden.
    private let quickAmounts = [250, 330, 500, 750]

    // MARK: - Initialisierung

    init(
        selectedDate: Date = .now,
        accentColor: Color = .blue,
        entryToEdit: WaterEntry? = nil,
        onAddWater: @escaping (Int) -> Void = { _ in }
    ) {
        self.selectedDate = selectedDate
        self.accentColor = accentColor
        self.entryToEdit = entryToEdit
        self.onAddWater = onAddWater
        _editingEntry = State(initialValue: entryToEdit)
        _customAmountText = State(
            initialValue: entryToEdit.map { String($0.amount) } ?? ""
        )
    }

    // MARK: - Ansicht

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if editingEntry == nil {
                        quickAddCard
                    }
                    customAmountCard
                    dailyLogCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Wasser hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .confirmationDialog(
                "Wassereintrag löschen?",
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
            } message: {
                if let entryToDelete {
                    Text("\(formattedAmount(entryToDelete.amount)) ml um \(entryToDelete.date, format: .dateTime.hour().minute()) wirklich löschen?")
                }
            }
            .alert(
                "Eintrag konnte nicht gelöscht werden",
                isPresented: Binding(
                    get: { deleteErrorMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            deleteErrorMessage = nil
                        }
                    }
                )
            ) {
                Button("OK") {
                    deleteErrorMessage = nil
                }
            } message: {
                Text(deleteErrorMessage ?? "Unbekannter Fehler")
            }
        }
    }

    // MARK: - Schnell hinzufügen

    private var quickAddCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Schnell hinzufügen", systemImage: "bolt.fill")

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(quickAmounts, id: \.self) { amount in
                    Button { addWater(amount) } label: {
                        VStack(spacing: 7) {
                            Image(systemName: "drop.fill")
                                .font(.title3)
                            Text("+ " + formattedAmount(amount) + " ml")
                                .font(.body.weight(.semibold))
                        }
                        .foregroundStyle(accentColor)
                        .frame(maxWidth: .infinity, minHeight: 68)
                        .background(
                            accentColor.opacity(0.10),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(formattedAmount(amount)) Milliliter hinzufügen")
                }
            }
        }
        .appCard()
    }

    // MARK: - Eigene Menge

    private var customAmountCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                editingEntry == nil ? "Eigene Menge" : "Menge bearbeiten",
                systemImage: "slider.horizontal.3"
            )

            HStack(spacing: 12) {
                TextField("z. B. 330", text: $customAmountText)
                    .keyboardType(.numberPad)
                    .focused($customAmountFocused)
                    .submitLabel(.done)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(
                        Color(.tertiarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )

                Text("ml")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)

                Button {
                    if editingEntry == nil {
                        addCustomAmount()
                    } else {
                        updateWaterEntry()
                    }
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
                .disabled(customAmount == nil)
                .accessibilityLabel(
                    editingEntry == nil ? "Eigene Menge hinzufügen" : "Wassermenge speichern"
                )
            }
        }
        .appCard()
    }

    // MARK: - Tageslogbuch

    private var dailyLogCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Tageslogbuch", systemImage: "clock.fill")

            if entriesForSelectedDay.isEmpty {
                Text("Für diesen Tag gibt es noch keine Einträge.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(entriesForSelectedDay) { entry in
                        HStack(spacing: 12) {
                            Image(systemName: "drop")
                                .foregroundStyle(accentColor)
                                .frame(width: 28)

                            Text(formattedAmount(entry.amount) + " ml")
                                .font(.body.weight(.medium))

                            Spacer()

                            Text(entry.date, format: .dateTime.hour().minute())
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()

                            Button {
                                entryToDelete = entry
                            } label: {
                                Image(systemName: "trash")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.red)
                                    .frame(width: 32, height: 32)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(
                                "\(formattedAmount(entry.amount)) Milliliter löschen"
                            )
                        }
                        .padding(.vertical, 9)

                        if entry.id != entriesForSelectedDay.last?.id {
                            Divider()
                                .padding(.leading, 40)
                        }
                    }
                }
            }
        }
        .appCard()
    }

    // MARK: - Aktionen und Werte

    private func sectionTitle(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
    }

    private var customAmount: Int? {
        let digits = customAmountText.filter(\.isNumber)
        guard let amount = Int(digits), amount > 0 else { return nil }
        return amount
    }

    private var entriesForSelectedDay: [WaterEntry] {
        waterEntries.filter {
            Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
        }
    }

    private func addCustomAmount() {
        guard let amount = customAmount else { return }
        addWater(amount)
    }

    private func addWater(_ amount: Int) {
        guard amount > 0 else { return }
        onAddWater(amount)
        customAmountText = ""
        customAmountFocused = false
        dismiss()
    }

    // MARK: - Bearbeiten

    /// Aktualisiert einen bestehenden Wasserwert inklusive Zeitstempel.
    private func updateWaterEntry() {
        guard let amount = customAmount, let editingEntry else { return }

        editingEntry.update(amount: amount)

        do {
            try modelContext.save()
            self.editingEntry = nil
            customAmountText = ""
            customAmountFocused = false
        } catch {
            logger.error("Wassereintrag konnte nicht aktualisiert werden: \(error.localizedDescription)")
            deleteErrorMessage = "Der Wassereintrag konnte nicht aktualisiert werden."
        }
    }

    // MARK: - Löschen

    /// Löscht den bestätigten Eintrag aus SwiftData.
    /// SwiftData/CloudKit übernimmt anschließend die geräteübergreifende
    /// Löschung über den bestehenden nativen Synchronisations-Stack.
    private func deleteSelectedEntry() {
        guard let entryToDelete else { return }

        modelContext.delete(entryToDelete)
        self.entryToDelete = nil

        do {
            try modelContext.save()
        } catch {
            logger.error(
                "Wassereintrag konnte nicht gelöscht werden: \(error.localizedDescription)"
            )
            deleteErrorMessage = "Der Wassereintrag konnte nicht gelöscht werden."
        }
    }

    private func formattedAmount(_ amount: Int) -> String {
        amount.formatted(.number.locale(Locale(identifier: "de_DE")))
    }
}

#Preview("AddWaterView") {
    AddWaterView(accentColor: .teal)
        .modelContainer(for: [WaterEntry.self], inMemory: true)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
}
