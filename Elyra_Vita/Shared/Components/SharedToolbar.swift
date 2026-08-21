import SwiftUI
import PasukiUI

// MARK: - SharedToolbar

/// Aktionen, die im Plus-Menü der jeweiligen App-Seite angeboten werden.
enum SharedToolbarAction: String, CaseIterable, Identifiable {

    // MARK: - Aktionen

    case meal
    case water
    case weight
    case breakfast
    case lunch
    case dinner
    case snack

    // MARK: - Identifiable

    var id: Self { self }

    // MARK: - Seitenkonfiguration

    /// Aktionen für die Übersicht.
    static var overview: [Self] {
        [.meal, .water, .weight]
    }

    /// Aktionen für den Ernährungsbereich.
    static var nutrition: [Self] {
        [.breakfast, .lunch, .dinner, .snack, .water]
    }

    // MARK: - Darstellung

    var title: String {
        switch self {
        case .meal:
            "Mahlzeit erfassen"
        case .water:
            "Wasser hinzufügen"
        case .weight:
            "Gewicht erfassen"
        case .breakfast:
            "Frühstück erfassen"
        case .lunch:
            "Mittagessen erfassen"
        case .dinner:
            "Abendessen erfassen"
        case .snack:
            "Snack erfassen"
        }
    }

    var systemImage: String {
        switch self {
        case .meal, .breakfast, .lunch, .dinner, .snack:
            "fork.knife"
        case .water:
            "drop"
        case .weight:
            "scalemass"
        }
    }
}

// MARK: - SharedToolbar

/// Gemeinsame Toolbar mit seitenabhängig konfigurierbarem Plus-Menü.
struct SharedToolbar: ToolbarContent {
    // MARK: - Daten und Aktionen

    let title: String
    let onPrevious: () -> Void
    let onSelectDate: () -> Void
    let onNext: () -> Void
    let menuActions: [SharedToolbarAction]
    let onMenuAction: (SharedToolbarAction) -> Void
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
                labels: .init(
                    previous: "Vorheriger Tag",
                    selection: "Datum auswählen",
                    next: "Nächster Tag"
                ),
                onPrevious: onPrevious,
                onSelect: onSelectDate,
                onNext: onNext
            )
        }

        // Rechte Seite: die für den aktiven Bereich konfigurierten Aktionen.
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                ForEach(menuActions) { action in
                    Button {
                        onMenuAction(action)
                    } label: {
                        Label(action.title, systemImage: action.systemImage)
                    }
                    .accessibilityIdentifier("toolbar.action.\(action.rawValue)")
                }
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Eintrag hinzufügen")
            .accessibilityIdentifier("toolbar.addMenu")
        }
    }
}
