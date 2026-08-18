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
    // MARK: - Gemeinsamer ModelContainer

    /// Der zentrale SwiftData-Container der App.
    /// Er kennt alle Modelle und verwaltet den dauerhaften Speicher.
    var sharedModelContainer: ModelContainer = {
        // Das Schema beschreibt die Modelle, die SwiftData speichern darf.
        let schema = Schema([
            UserSettings.self
        ])

        // Die Daten bleiben auch nach dem Neustart der App erhalten.
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

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
