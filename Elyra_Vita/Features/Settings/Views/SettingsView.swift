import SwiftData
import OSLog
import StoreKit
import SwiftUI
import UniformTypeIdentifiers
import PasukiUI

// MARK: - SettingsView

/// Verwaltet Profil, Tagesziele, Darstellung und Support-Einstellungen.
struct SettingsView: View {
    // MARK: - Abhängigkeiten und Zustand

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var proAccess: PasukiStoreKitProService
    @EnvironmentObject private var syncMonitor: PasukiCloudKitSyncMonitor

    private let configuration = PasukiSettingsConfiguration(
        appName: "Elyra Vita",
        supportURL: "mailto:support@pasukistudio.de?subject=Elyra%20Vita%20Support",
        privacyURL: "https://pasukistudio.de/datenschutz/",
        eulaURL: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/",
        projectURL: "https://github.com/pasukistudio/elyra-vita",
        issuesURL: "https://github.com/pasukistudio/elyra-vita/issues",
        customColorProMessage: "Eigene Farben sind Bestandteil von Elyra Vita Pro."
    )

    @State private var draftName = ""
    @State private var saveErrorMessage: String?
    @State private var storeErrorMessage: String?
    @State private var isProcessingStoreAction = false

    private let logger = Logger(
        subsystem: "de.pasukistudio.elyra-vita",
        category: "Settings"
    )

    // MARK: - Persistierte Profile
    @Query(
        sort: \UserSettings.updatedAt,
        order: .reverse
    )
    private var profiles: [UserSettings]

    // MARK: - Ansicht

    var body: some View {
        Form {
            profileSection
            dailyGoalsSection
            appearanceSection
            accentColorSection
            syncSection
            proSection
            PasukiSupportSection(supportURL: url(configuration.supportURL))
            PasukiLegalSection(
                privacyURL: url(configuration.privacyURL),
                eulaURL: url(configuration.eulaURL)
            )
            PasukiAboutSection(
                appName: configuration.appName,
                appVersion: appVersion,
                projectURL: url(configuration.projectURL),
                issuesURL: url(configuration.issuesURL)
            )
        }
        .navigationTitle("Einstellungen")

        .navigationBarTitleDisplayMode(.inline)

        .task {
            createProfileIfNeeded()
        }
        .onChange(
            of: profiles.first?.updatedAt,
            initial: true
        ) {
            loadDraftName()
        }
        .onDisappear {
            saveName()
        }
        .alert(
            "Einstellungen konnten nicht gespeichert werden",
            isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        saveErrorMessage = nil
                    }
                }
            )
        ) {
            Button("OK") {
                saveErrorMessage = nil
            }
        } message: {
            Text(saveErrorMessage ?? "Unbekannter Fehler")
        }
        .alert(
            "Pro konnte nicht aktiviert werden",
            isPresented: Binding(
                get: { storeErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        storeErrorMessage = nil
                    }
                }
            )
        ) {
            Button("OK") {
                storeErrorMessage = nil
            }
        } message: {
            Text(storeErrorMessage ?? "Unbekannter StoreKit-Fehler")
        }
    }

    // MARK: - Tagesziele Sektion

    // MARK: - Synchronisierung

    private var syncSection: some View {
        Section("Synchronisierung") {
            PasukiCloudKitSyncStatusView(status: syncMonitor.status)
        }
    }

    @ViewBuilder
    private var dailyGoalsSection: some View {
        Section("Tagesziele") {
            if let profile = profiles.first {
                Stepper(
                    value: Binding(
                        get: { profile.calorieGoal },
                        set: { value in
                            profile.calorieGoal = value
                            profile.markUpdated()
                            saveSettings()
                        }
                    ),
                    in: 1_000...6_000,
                    step: 100
                ) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Kalorienziel")
                            .font(.body.weight(.medium))

                        Text("\(profile.calorieGoal.formatted(.number.locale(Locale(identifier: "de_DE")))) kcal pro Tag")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Stepper(
                    value: Binding(
                        get: { profile.waterGoalML },
                        set: { value in
                            profile.waterGoalML = value
                            profile.markUpdated()
                            saveSettings()
                        }
                    ),
                    in: 500...6_000,
                    step: 250
                ) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Wasserziel")
                            .font(.body.weight(.medium))

                        Text("\(profile.waterGoalML.formatted(.number.locale(Locale(identifier: "de_DE")))) ml pro Tag")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                ProgressView()
            }
        }
    }

    // MARK: - Profil Sektion

    @ViewBuilder
    private var profileSection: some View {
        Section("Profil") {
            if profiles.first != nil {
                TextField(
                    "Dein Name",
                    text: $draftName
                )
                .textContentType(.name)

                .submitLabel(.done)

                .onSubmit {
                    saveName()
                }
            } else {
                ProgressView()
            }
        }
    }

    // MARK: - Erscheinungsbild Sektion

    @ViewBuilder
    private var appearanceSection: some View {
        Section("Darstellung") {
            if let profile = profiles.first {
                Picker(
                    "Erscheinungsbild",
                    selection: Binding(
                        get: {
                            AppAppearance(
                                rawValue: profile.appearanceRawValue
                            ) ?? .system
                        },
                        set: { appearance in
                            profile.appearanceRawValue =
                            appearance.rawValue

                            profile.markUpdated()
                            saveSettings()
                        }
                    )
                ) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Label(
                            appearance.title,
                            systemImage: appearance.icon
                        )
                        .tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    // MARK: - Akzentfarbe Sektion

    // MARK: - Pro Sektion

    @ViewBuilder
    private var proSection: some View {
        Section("Elyra Vita Pro") {
            if proAccess.hasAccess(to: .customAccentColor) {
                Label("Pro ist aktiviert", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            } else if let product = proAccess.products.first {
                Button {
                    Task {
                        await purchase(product)
                    }
                } label: {
                    HStack {
                        Label("Pro freischalten", systemImage: "star.fill")
                        Spacer()
                        Text(product.displayPrice)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(isProcessingStoreAction)
            } else if proAccess.state == .loading {
                HStack {
                    ProgressView()
                    Text("StoreKit wird geladen …")
                }
            } else {
                Text("Pro ist derzeit nicht verfügbar.")
                    .foregroundStyle(.secondary)
            }

            Button("Käufe wiederherstellen") {
                Task {
                    await restorePurchases()
                }
            }
            .disabled(isProcessingStoreAction)
        }
    }

    @ViewBuilder
    private var accentColorSection: some View {
        Section {
            if let profile = profiles.first {
                customColorRow(profile: profile)
            }
        } header: {
            Text("Akzentfarbe")
        } footer: {
            Text(configuration.customColorProMessage)
        }
    }

    private func customColorRow(
        profile: UserSettings
    ) -> some View {
        PresetColorSelectionView(
            selection: Binding(
                get: { profile.customAccentHex },
                set: { profile.customAccentHex = $0 }
            ),
            title: "Akzentfarbe",
            onPresetSelected: { preset in
                profile.customAccentHex = preset.hex
                profile.accentColorRawValue =
                AppAccentColor(rawValue: preset.rawValue).rawValue
                profile.markUpdated()
                saveSettings()
            },
            onCustomColorChanged: { hex in
                profile.customAccentHex = hex
                profile.accentColorRawValue = AppAccentColor.custom.rawValue
                profile.markUpdated()
                saveSettings()
            },
            proAccess: proAccess
        )
    }

    // MARK: - StoreKit-Aktionen

    private func purchase(_ product: Product) async {
        isProcessingStoreAction = true
        defer { isProcessingStoreAction = false }

        do {
            _ = try await proAccess.purchase(product)
        } catch {
            storeErrorMessage = error.localizedDescription
        }
    }

    private func restorePurchases() async {
        isProcessingStoreAction = true
        defer { isProcessingStoreAction = false }

        do {
            try await proAccess.restorePurchases()
        } catch {
            storeErrorMessage = error.localizedDescription
        }
    }


    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–"
        return "\(version) (Build \(build))"
    }

    // MARK: - URL-Hilfen

    private func url(_ string: String) -> URL? {
        URL(string: string)
    }

    // MARK: - Namensverwaltung

    private func loadDraftName() {
        guard let profile = profiles.first else {
            return
        }

        draftName = profile.name
    }

    private func saveName() {
        guard let profile = profiles.first else {
            return
        }

        let cleanedName = draftName
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard profile.name != cleanedName else {
            return
        }

        profile.name = cleanedName
        profile.markUpdated()

        saveSettings()
    }

    // MARK: - SwiftData

    private func createProfileIfNeeded() {
        guard profiles.isEmpty else {
            return
        }

        let profile = UserSettings()
        modelContext.insert(profile)

        saveSettings()
    }

    private func saveSettings() {
        guard modelContext.hasChanges else {
            return
        }

        do {
            try modelContext.save()
        } catch {
            logger.error(
                "UserSettings konnten nicht gespeichert werden: \(error.localizedDescription)"
            )
            saveErrorMessage =
            "Die Einstellungen konnten nicht gespeichert werden."
        }
    }
}
