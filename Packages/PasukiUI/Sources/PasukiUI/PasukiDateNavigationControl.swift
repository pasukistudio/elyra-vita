import SwiftUI

// MARK: - PasukiDateNavigationLabels

/// Accessibility-Texte für eine Datumsnavigation.
///
/// Die Komponente kennt absichtlich weder Tage noch Monate. Die jeweilige App
/// liefert die passenden Texte und kann denselben Baustein dadurch für beide
/// Navigationsarten verwenden.
public struct PasukiDateNavigationLabels: Sendable {

    // MARK: - Texte

    public let previous: String
    public let selection: String
    public let next: String

    // MARK: - Initialisierung

    public init(
        previous: String = "Previous",
        selection: String = "Select date",
        next: String = "Next"
    ) {
        self.previous = previous
        self.selection = selection
        self.next = next
    }
}

// MARK: - PasukiDateNavigationControl

/// Wiederverwendbare Navigation mit Zurück-, Auswahl- und Weiter-Aktion.
public struct PasukiDateNavigationControl: View {

    // MARK: - Eingaben

    public let title: String
    public let labels: PasukiDateNavigationLabels
    public let onPrevious: () -> Void
    public let onSelect: () -> Void
    public let onNext: () -> Void

    // MARK: - Initialisierung

    public init(
        title: String,
        labels: PasukiDateNavigationLabels = .init(),
        onPrevious: @escaping () -> Void,
        onSelect: @escaping () -> Void,
        onNext: @escaping () -> Void
    ) {
        self.title = title
        self.labels = labels
        self.onPrevious = onPrevious
        self.onSelect = onSelect
        self.onNext = onNext
    }

    // MARK: - Ansicht

    public var body: some View {
        HStack(spacing: 10) {
            navigationButton(
                systemImage: "chevron.left",
                accessibilityLabel: labels.previous,
                action: onPrevious
            )

            Button(action: onSelect) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(minWidth: 135)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(labels.selection)

            navigationButton(
                systemImage: "chevron.right",
                accessibilityLabel: labels.next,
                action: onNext
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    // MARK: - Unteransichten

    private func navigationButton(
        systemImage: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
