import Foundation

// MARK: - PasukiTimestampConflictPolicy

/// Gemeinsame Last-Write-Wins-Regel für zeitgestempelte Datensätze.
///
/// SwiftData/CloudKit bleibt für die eigentliche Synchronisierung zuständig.
/// Diese kleine, deterministische Regel steht für Stellen bereit, an denen
/// die App zwei bereits geladene Versionen explizit vergleichen muss.
public enum PasukiTimestampConflictPolicy {

    // MARK: - Konfliktentscheidung

    /// Liefert `true`, wenn die Remote-Version die lokale Version ersetzt.
    /// Bei identischen Zeitstempeln bleibt die lokale Version stabil.
    public static func shouldApplyRemoteChange(
        localUpdatedAt: Date,
        remoteUpdatedAt: Date
    ) -> Bool {
        remoteUpdatedAt > localUpdatedAt
    }
}
