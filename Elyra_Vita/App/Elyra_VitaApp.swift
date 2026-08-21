//
//  Elyra_VitaApp.swift
//  Elyra_Vita
//
//  Created by Pascal Smigielski on 14.08.26.
//

import SwiftUI
import SwiftData

@main
struct Elyra_VitaApp: App {

    // MARK: - CloudKit

    /// Der von Apple verwaltete private CloudKit-Container für SwiftData.
    private static let cloudKitContainerIdentifier =
        "iCloud.de.pasukistudio.elyra-vita"

    /// Deaktiviert CloudKit ausschließlich für isolierte Xcode-Testläufe.
    /// Geräte-Builds verwenden weiterhin immer den privaten CloudKit-Container.
    private static var cloudKitDatabase: ModelConfiguration.CloudKitDatabase {
        let environment = ProcessInfo.processInfo.environment
        let isTestProcess = environment["XCTestConfigurationFilePath"] != nil ||
            environment["XCInjectBundleInto"] != nil ||
            environment["ELYRA_VITA_DISABLE_CLOUDKIT"] == "YES" ||
            ProcessInfo.processInfo.arguments.contains("--disable-cloudkit") ||
            environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

        if isTestProcess {
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

    // MARK: - App-Szene

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Macht den Container fuer alle untergeordneten Views verfuegbar.
        .modelContainer(sharedModelContainer)
    }
}
