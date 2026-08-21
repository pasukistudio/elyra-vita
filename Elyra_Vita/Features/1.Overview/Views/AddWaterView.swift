import SwiftUI
import SwiftData
import PasukiUI

// MARK: - AddWaterView

/// Erfasst schnelle oder frei eingegebene Wasserportionen und zeigt das
/// Trinkprotokoll des ausgewählten Tages an.
struct AddWaterView: View {
    // MARK: - Umgebung und Eingaben

    @Environment(\.dismiss) private var dismiss
    @State private var customAmountText = ""
    @FocusState private var customAmountFocused: Bool

    /// Das Datum, für das der Eintrag und das Logbuch gelten.
    let selectedDate: Date

    @Query(sort: \WaterEntry.date, order: .reverse)
    private var waterEntries: [WaterEntry]

    /// Akzentfarbe aus den App-Einstellungen.
    let accentColor: Color

    /// Übergibt eine Menge an die spätere HealthKit-/SwiftData-Anbindung.
    let onAddWater: (Int) -> Void

    /// Häufige Portionsgrößen, die ohne Tastatureingabe hinzugefügt werden.
    private let quickAmounts = [250, 330, 500, 750]

    // MARK: - Initialisierung

    init(
        selectedDate: Date = .now,
        accentColor: Color = .blue,
        onAddWater: @escaping (Int) -> Void = { _ in }
    ) {
        self.selectedDate = selectedDate
        self.accentColor = accentColor
        self.onAddWater = onAddWater
    }

    // MARK: - Ansicht

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    quickAddCard
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
            sectionTitle("Eigene Menge", systemImage: "slider.horizontal.3")

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

                Button { addCustomAmount() } label: {
                    Image(systemName: "plus")
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
                .accessibilityLabel("Eigene Menge hinzufügen")
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

    private func sectionTitle(_ title: LocalizedStringKey, systemImage: String) -> some View {
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
