import SwiftUI

// MARK: - AppSection

/// Die vier Hauptbereiche der Tab-Navigation.
enum AppSection: String, CaseIterable, Identifiable {
    // MARK: - Tab-Bereiche

    case overview
    case nutrition
    case planning
    case recipies

    // MARK: - Identifiable

    var id: Self {
        self
    }

    // MARK: - Anzeigename

    var title: LocalizedStringResource {
        switch self {
        case .overview:
            return "Übersicht"

        case .nutrition:
            return "Ernährung"

        case .planning:
            return "Planung"

        case .recipies:
            return "Rezepte"
        }
    }

    // MARK: - Tab-Symbol

    var icon: String {
        switch self {
        case .overview:
            return "house"

        case .nutrition:
            return "fork.knife"

        case .planning:
            return "calendar.badge.checkmark"

        case .recipies:
            return "book.closed.fill"
        }
    }
}
