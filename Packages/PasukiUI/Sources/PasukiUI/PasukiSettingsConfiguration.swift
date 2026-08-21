import Foundation

// MARK: - PasukiSettingsConfiguration

/// Produktneutrale Inhalte für eine gemeinsame Settings-Struktur.
///
/// Das Modell enthält bewusst nur Konfiguration. Speicherung, SwiftData und
/// fachliche Sektionen bleiben in der jeweiligen App.
public struct PasukiSettingsConfiguration: Sendable {

    // MARK: - Inhalte

    public let appName: String
    public let supportURL: String
    public let privacyURL: String
    public let eulaURL: String
    public let projectURL: String
    public let issuesURL: String
    public let customColorProMessage: String

    // MARK: - Initialisierung

    public init(
        appName: String,
        supportURL: String,
        privacyURL: String,
        eulaURL: String,
        projectURL: String,
        issuesURL: String,
        customColorProMessage: String
    ) {
        self.appName = appName
        self.supportURL = supportURL
        self.privacyURL = privacyURL
        self.eulaURL = eulaURL
        self.projectURL = projectURL
        self.issuesURL = issuesURL
        self.customColorProMessage = customColorProMessage
    }
}
