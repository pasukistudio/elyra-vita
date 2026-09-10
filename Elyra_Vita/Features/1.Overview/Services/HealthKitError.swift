import Foundation

enum HealthKitError: LocalizedError {
    case unavailable
    case invalidDate

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Apple Health ist auf diesem Gerät nicht verfügbar."
        case .invalidDate:
            return "Das ausgewählte Datum konnte nicht verarbeitet werden."
        }
    }
}
