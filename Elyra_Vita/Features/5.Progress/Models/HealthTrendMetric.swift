import SwiftUI

// MARK: - HealthTrendRange

/// Zeiträume, die für alle Gesundheitstrends einheitlich angeboten werden.
enum HealthTrendRange: String, CaseIterable, Identifiable {
    case week
    case month
    case threeMonths
    case year

    var id: Self { self }

    var title: String {
        switch self {
        case .week: "Woche"
        case .month: "Monat"
        case .threeMonths: "3 Monate"
        case .year: "Jahr"
        }
    }

    var days: Int {
        switch self {
        case .week: 7
        case .month: 30
        case .threeMonths: 90
        case .year: 365
        }
    }

}

// MARK: - HealthTrendMetric

/// Einheitliche Beschreibung der aus der Übersicht öffnbaren Gesundheitswerte.
enum HealthTrendMetric: String, CaseIterable, Identifiable {
    case calories
    case steps
    case walkingRunningDistance
    case activeEnergy
    case basalEnergy
    case totalEnergy
    case protein
    case carbohydrates
    case fat
    case weight
    case water

    var id: Self { self }

    var title: String {
        switch self {
        case .calories: "Kalorien"
        case .steps: "Schritte"
        case .walkingRunningDistance: "Geh-/Laufdistanz"
        case .activeEnergy: "Aktiv verbrannt"
        case .basalEnergy: "Ruheenergie"
        case .totalEnergy: "Gesamtverbrauch"
        case .protein: "Eiweiß"
        case .carbohydrates: "Kohlenhydrate"
        case .fat: "Fett"
        case .weight: "Gewicht"
        case .water: "Wasser"
        }
    }

    var systemImage: String {
        switch self {
        case .calories: "flame.fill"
        case .steps: "shoeprints.fill"
        case .walkingRunningDistance: "mappin.and.ellipse"
        case .activeEnergy: "figure.run"
        case .basalEnergy: "figure.mind.and.body"
        case .totalEnergy: "bolt.fill"
        case .protein: "fork.knife"
        case .carbohydrates: "leaf.fill"
        case .fat: "drop.triangle.fill"
        case .weight: "scalemass"
        case .water: "drop.fill"
        }
    }

    var color: Color {
        switch self {
        case .calories: .orange
        case .steps: .green
        case .walkingRunningDistance: .blue
        case .activeEnergy: .teal
        case .basalEnergy: .secondary
        case .totalEnergy: .orange
        case .protein: .blue
        case .carbohydrates: .teal
        case .fat: .purple
        case .weight: .cyan
        case .water: .blue
        }
    }

    var unit: String {
        switch self {
        case .calories: "kcal"
        case .steps: "Schritte"
        case .walkingRunningDistance: "km"
        case .activeEnergy, .basalEnergy, .totalEnergy: "kcal"
        case .protein, .carbohydrates, .fat: "g"
        case .weight: "kg"
        case .water: "ml"
        }
    }

    var usesHealthKit: Bool {
        self != .calories && self != .weight && self != .water
    }
}

// MARK: - HealthTrendPoint

/// Ein darstellbarer Trendpunkt mit Datum und bereits normalisiertem Wert.
struct HealthTrendPoint: Identifiable, Sendable {
    let date: Date
    let value: Double

    var id: Date { date }
}
