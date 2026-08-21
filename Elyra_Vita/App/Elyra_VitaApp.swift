import SwiftUI
import SwiftData
import PasukiUI

// MARK: - Elyra_VitaApp

/// Einstiegspunkt der App und Besitzer des gemeinsamen SwiftData-Containers.
@main
struct Elyra_VitaApp: App {

    // MARK: - StoreKit / Pro

    /// Produktzuordnung der App. Die ID muss in App Store Connect exakt
    /// dieselbe Schreibweise verwenden.
    private static let proConfiguration = PasukiProProductConfiguration(
        featureByProductIdentifier: [
            "de.pasukistudio.elyra-vita.pro": .customAccentColor
        ]
    )

    @StateObject private var proAccess: PasukiStoreKitProService

    // MARK: - Initialisierung

    init() {
        _proAccess = StateObject(
            wrappedValue: PasukiStoreKitProService(
                configuration: Self.proConfiguration
            )
        )
        _syncMonitor = StateObject(
            wrappedValue: PasukiCloudKitSyncMonitor(
                isEnabled: !Self.cloudKitIsDisabled
            )
        )
    }

    // MARK: - CloudKit

    /// Der von Apple verwaltete private CloudKit-Container für SwiftData.
    private static let cloudKitContainerIdentifier =
        "iCloud.de.pasukistudio.elyra-vita"

    /// Deaktiviert CloudKit ausschließlich für isolierte Xcode-Testläufe.
    /// Geräte-Builds verwenden weiterhin immer den privaten CloudKit-Container.
    private static var cloudKitIsDisabled: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil ||
            environment["XCInjectBundleInto"] != nil ||
            environment["ELYRA_VITA_DISABLE_CLOUDKIT"] == "YES" ||
            ProcessInfo.processInfo.arguments.contains("--disable-cloudkit") ||
            environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private static var cloudKitDatabase: ModelConfiguration.CloudKitDatabase {
        if cloudKitIsDisabled {
            return .none
        }

        return .private(cloudKitContainerIdentifier)
    }

    // MARK: - Gemeinsamer ModelContainer

    /// Der zentrale SwiftData-Container der App.
    /// Er kennt alle Modelle und verwaltet den dauerhaften Speicher.
    var sharedModelContainer: ModelContainer = {
        // Das Schema beschreibt die Modelle, die SwiftData speichern darf.
        let schema = Schema([
            UserSettings.self,
            WaterEntry.self
        ])

        // Die Daten bleiben auch nach dem Neustart der App erhalten.
        // SwiftData übernimmt Synchronisierung, Offline-Pufferung und
        // Konfliktverarbeitung über Apples NSPersistentCloudKitContainer.
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: cloudKitDatabase
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Ohne Container kann die App nicht mit SwiftData arbeiten.
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // MARK: - CloudKit-Status

    @StateObject private var syncMonitor: PasukiCloudKitSyncMonitor

    // MARK: - App-Szene

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(proAccess)
                .environmentObject(syncMonitor)
                .task {
                    await proAccess.refresh()
                }
        }
        // Macht den Container fuer alle untergeordneten Views verfuegbar.
        .modelContainer(sharedModelContainer)
    }
}
