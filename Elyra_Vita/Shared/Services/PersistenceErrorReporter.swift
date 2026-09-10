import Foundation
import OSLog
import SwiftData

extension Notification.Name {
    static let persistenceError = Notification.Name("ElyraVita.PersistenceError")
}

/// Zentrale, einheitliche Fehlerbehandlung für SwiftData-Speichervorgänge.
@MainActor
enum PersistenceErrorReporter {
    @discardableResult
    static func save(
        _ context: ModelContext,
        operation: String,
        onError: ((String) -> Void)? = nil
    ) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            context.rollback()
            let message = error.localizedDescription
            Logger(
                subsystem: "de.pasukistudio.elyra-vita",
                category: "Persistence"
            ).error("\(operation, privacy: .public) fehlgeschlagen: \(message, privacy: .public)")
            onError?(message)

            // Views mit eigenem Fehlerzustand zeigen die Meldung selbst.
            // Der globale Alert ist der Fallback für Aufrufer ohne Callback.
            if onError == nil {
                NotificationCenter.default.post(
                    name: .persistenceError,
                    object: message
                )
            }
            return false
        }
    }
}
