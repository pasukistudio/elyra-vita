import SwiftUI

struct DateNavigationControl: View {
    // MARK: - Anzeige

    let title: String

    // MARK: - Aktionen

    let onPrevious: () -> Void
    let onSelectDate: () -> Void
    let onNext: () -> Void

    // MARK: - Ansicht

    var body: some View {
        HStack(spacing: 10) {
            previousButton
            dateButton
            nextButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    // MARK: - Vorheriger Tag

    private var previousButton: some View {
        Button(
            action: onPrevious
        ) {
            Image(systemName: "chevron.left")
                .frame(
                    width: 30,
                    height: 30
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Vorheriger Tag")
    }
    // MARK: - Datums-Auswahl

    private var dateButton: some View {
        Button(
            action: onSelectDate
        ) {
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(minWidth: 135)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Datum auswählen")
    }

    // MARK: - Naechster Tag

    private var nextButton: some View {
        Button(
            action: onNext
        ) {
            Image(systemName: "chevron.right")
                .frame(
                    width: 30,
                    height: 30
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Nächster Tag")
    }
}

#Preview("Datumsnavigation") {
    DateNavigationControl(
        title: "September 2026",
        onPrevious: {},
        onSelectDate: {},
        onNext: {}
    )
    .padding()
}
