import SwiftUI

struct SharedToolbar: ToolbarContent {
    // MARK: - Daten und Aktionen

    let title: String
    let onPrevious: () -> Void
    let onSelectDate: () -> Void
    let onNext: () -> Void
    let onAdd: () -> Void
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
                    onAdd()
                } label: {
                    Label("Wasser hinzufügen", systemImage: "drop")
                }

                Button {
                    onAdd()
                } label: {
                    Label("Mahlzeit erfassen", systemImage: "fork.knife")
                }

                Button {
                    onAdd()
                } label: {
                    Label("Gewicht erfassen", systemImage: "scalemass")
                }
            } label: {
                Image(systemName: "plus")
            }
        }
    }
}
