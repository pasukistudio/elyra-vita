import PasukiUI
import SwiftUI

extension AddWaterView {
    var dailyLogCard: some View {
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
}
