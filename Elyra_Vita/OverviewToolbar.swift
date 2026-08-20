import SwiftUI

struct OverviewToolbar: ToolbarContent {
    // MARK: - Daten und Aktionen

    let title: String
    let onPrevious: () -> Void
    let onSelectDate: () -> Void
    let onNext: () -> Void
    let onAddWater: () -> Void
    let onAddMeal: () -> Void
    let onAddWeight: () -> Void
    let onSettings: () -> Void

    // MARK: - Toolbar-Inhalt

    var body: some ToolbarContent {
        // Linke Seite: Einstellungen oeffnen.
        ToolbarItem(placement: .topBarLeading) {
            Button(action: onSettings) {
                Image(systemName: "person.fill")
            }
            .accessibilityLabel("Einstellungen")
        }

        // Mitte: Durch Tage navigieren und ein Datum auswaehlen.
        ToolbarItem(placement: .principal) {
            DateNavigationControl(
                title: title,
                onPrevious: onPrevious,
                onSelectDate: onSelectDate,
                onNext: onNext
            )
        }

        // Rechte Seite: Menue fuer neue Eintraege.
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    onAddWater()
                } label: {
                    Label("Wasser hinzufügen", systemImage: "drop")
                }

                Button {
                    onAddMeal()
                } label: {
                    Label("Mahlzeit erfassen", systemImage: "fork.knife")
                }

                Button {
                    onAddWeight()
                } label: {
                    Label("Gewicht erfassen", systemImage: "scalemass")
                }
            } label: {
                Image(systemName: "plus")
            }
        }
    }
}
