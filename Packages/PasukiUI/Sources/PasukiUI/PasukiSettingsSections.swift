import SwiftUI

// MARK: - PasukiSupportSection

/// Wiederverwendbare Support-Zeile für Produkt-Settings.
public struct PasukiSupportSection: View {

    // MARK: - Eingaben

    public let supportURL: URL?

    // MARK: - Initialisierung

    public init(supportURL: URL?) {
        self.supportURL = supportURL
    }

    // MARK: - Ansicht

    public var body: some View {
        Section("Hilfe & Support") {
            if let supportURL {
                Link(destination: supportURL) {
                    Label("Support per E-Mail", systemImage: "envelope.fill")
                }
            }
        }
    }
}

// MARK: - PasukiLegalSection

/// Wiederverwendbare Links für Datenschutz und Nutzungsbedingungen.
public struct PasukiLegalSection: View {

    // MARK: - Eingaben

    public let privacyURL: URL?
    public let eulaURL: URL?

    // MARK: - Initialisierung

    public init(privacyURL: URL?, eulaURL: URL?) {
        self.privacyURL = privacyURL
        self.eulaURL = eulaURL
    }

    // MARK: - Ansicht

    public var body: some View {
        Section("Rechtliches") {
            if let privacyURL {
                Link(destination: privacyURL) {
                    Label("Datenschutz", systemImage: "hand.raised.fill")
                }
            }

            if let eulaURL {
                Link(destination: eulaURL) {
                    Label("Nutzungsbedingungen (EULA)", systemImage: "doc.text.fill")
                }
            }
        }
    }
}

// MARK: - PasukiAboutSection

/// Wiederverwendbare Versions- und Projektinformationen.
public struct PasukiAboutSection: View {

    // MARK: - Eingaben

    public let appName: String
    public let appVersion: String
    public let projectURL: URL?
    public let issuesURL: URL?

    // MARK: - Initialisierung

    public init(
        appName: String,
        appVersion: String,
        projectURL: URL?,
        issuesURL: URL?
    ) {
        self.appName = appName
        self.appVersion = appVersion
        self.projectURL = projectURL
        self.issuesURL = issuesURL
    }

    // MARK: - Ansicht

    public var body: some View {
        Section("Über \(appName)") {
            LabeledContent("Version") {
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }

            if let projectURL {
                Link(destination: projectURL) {
                    Label("Projekt auf GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }

            if let issuesURL {
                Link(destination: issuesURL) {
                    Label("Fehler auf GitHub melden", systemImage: "ladybug")
                }
            }
        }
    }
}
