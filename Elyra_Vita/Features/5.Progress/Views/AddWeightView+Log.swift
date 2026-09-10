import PasukiUI
import SwiftUI

extension AddWeightView {
    var dailyLogCard: some View {
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
}
