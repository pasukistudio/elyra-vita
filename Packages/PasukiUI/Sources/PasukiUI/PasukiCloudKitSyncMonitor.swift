import CoreData
import Foundation
import SwiftUI

// MARK: - PasukiCloudKitSyncStatus

/// UI-relevanter Zustand der von Apple verwalteten CloudKit-Spiegelung.
public enum PasukiCloudKitSyncStatus: Equatable, Sendable {
    case unavailable
    case idle
    case syncing
    case synced(Date)
    case failed(message: String)

    // MARK: - Darstellung

    public var title: LocalizedStringResource {
        switch self {
        case .unavailable:
            "iCloud nicht aktiv"
        case .idle:
            "iCloud bereit"
        case .syncing:
            "iCloud wird synchronisiert"
        case .synced:
            "Mit iCloud synchronisiert"
        case .failed:
            "iCloud-Synchronisierung prüfen"
        }
    }

    public var systemImage: String {
        switch self {
        case .unavailable:
            "icloud.slash"
        case .idle, .synced:
            "checkmark.icloud"
        case .syncing:
            "arrow.triangle.2.circlepath.icloud"
        case .failed:
            "exclamationmark.icloud"
        }
    }

    public var tint: Color {
        switch self {
        case .unavailable, .failed:
            .orange
        case .idle, .synced:
            .green
        case .syncing:
            .blue
        }
    }
}

// MARK: - PasukiCloudKitSyncMonitor

/// Beobachtet Apples native CloudKit-Container-Events.
///
/// Es gibt keine eigene Upload-, Download- oder Konflikt-Engine. SwiftData
/// beziehungsweise Core Data bleibt für Persistenz und Konfliktverarbeitung
/// verantwortlich; dieser Monitor macht nur den von Apple gemeldeten Zustand
/// für die Oberfläche sichtbar.
@MainActor
public final class PasukiCloudKitSyncMonitor: ObservableObject {

    // MARK: - Zustand

    @Published public private(set) var status: PasukiCloudKitSyncStatus

    private var notificationToken: NSObjectProtocol?
    private let notificationCenter: NotificationCenter

    // MARK: - Initialisierung

    public init(
        isEnabled: Bool,
        notificationCenter: NotificationCenter = .default
    ) {
        self.notificationCenter = notificationCenter
        status = isEnabled ? .idle : .unavailable

        guard isEnabled else { return }

        notificationToken = notificationCenter.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let event = notification.userInfo?[
                NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            ] as? NSPersistentCloudKitContainer.Event else {
                return
            }

            Task { @MainActor [weak self] in
                self?.handle(event)
            }
        }
    }

    deinit {
        if let notificationToken {
            notificationCenter.removeObserver(notificationToken)
        }
    }

    // MARK: - Event-Verarbeitung

    private func handle(_ event: NSPersistentCloudKitContainer.Event) {
        guard event.endDate != nil else {
            status = .syncing
            return
        }

        if event.succeeded {
            status = .synced(event.endDate ?? .now)
        } else {
            status = .failed(
                message: event.error?.localizedDescription
                    ?? "Die Synchronisierung konnte nicht abgeschlossen werden."
            )
        }
    }
}

// MARK: - PasukiCloudKitSyncStatusView

/// Kompakte, wiederverwendbare Anzeige des nativen Sync-Zustands.
public struct PasukiCloudKitSyncStatusView: View {

    // MARK: - Eingaben

    private let status: PasukiCloudKitSyncStatus

    // MARK: - Initialisierung

    public init(status: PasukiCloudKitSyncStatus) {
        self.status = status
    }

    // MARK: - Ansicht

    public var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(status.title)
                    .font(.body.weight(.medium))

                if case .failed(let message) = status {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: status.systemImage)
                .foregroundStyle(status.tint)
        }
        .accessibilityValue(status.title)
    }
}
