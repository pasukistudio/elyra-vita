import SwiftData
import OSLog
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var draftName = ""
    @State private var saveErrorMessage: String?

    private let logger = Logger(
        subsystem: "de.pasukistudio.elyra-vita",
        category: "Settings"
    )


    @Query(
        sort: \UserSettings.updatedAt,
        order: .reverse
    )
    private var profiles: [UserSettings]

    var body: some View {
        Form {
            profileSection          //Profil Sektion
            dailyGoalsSection       //Tagesziele Sektion
            appearanceSection       //Erscheinungsbild Sektion
            accentColorSection      //Akzentfarbe Sektion
            supportSection          //Support Sektion
            legalSection            //Rechtliches Sektion
            aboutSection            //Über Sektion
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
    }

    // MARK: - Tagesziele Sektion

    @ViewBuilder
    private var dailyGoalsSection: some View {
        Section("Tagesziele") {
            if let profile = profiles.first {
                Stepper(
                    value: Binding(
                        get: { profile.waterGoalML },
                        set: { value in
                            profile.waterGoalML = value
                            profile.updatedAt = .now
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

                            profile.updatedAt = Date()
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

    @ViewBuilder
    private var accentColorSection: some View {
        Section {
            if let profile = profiles.first {
                customColorRow(profile: profile)
            }
        } header: {
            Text("Akzentfarbe")
        } footer: {
            Text(
                "Eigene Farben sind Bestandteil von Elyra Vita Pro."
            )
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
                AppAccentColor(rawValue: preset.rawValue)?.rawValue
                ?? AppAccentColor.blue.rawValue
                profile.updatedAt = .now
                saveSettings()
            },
            onCustomColorChanged: { hex in
                profile.customAccentHex = hex
                profile.accentColorRawValue = AppAccentColor.custom.rawValue
                profile.updatedAt = .now
                saveSettings()
            }
        )
    }


    // MARK: - Support Section

    private var supportSection: some View {
        Section("Hilfe & Support") {
            Link(destination: URL(string: "mailto:support@pasukistudio.de?subject=Elyra%20Vita%20Support")!) {
                Label("Support per E-Mail", systemImage: "envelope.fill")
            }
        }
    }


    // MARK: - Rechtliches Sektion

    private var legalSection: some View {
        Section("Rechtliches") {
            Link(destination: URL(string: "https://pasukistudio.de/datenschutz/")!) {
                Label("Datenschutz", systemImage: "hand.raised.fill")
            }

            Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                Label("Nutzungsbedingungen (EULA)", systemImage: "doc.text.fill")
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–"
        return "\(version) (Build \(build))"
    }

    // MARK: - Über Sektion

    private var aboutSection: some View {
        Section("Über Elyra Vita") {
            LabeledContent("Version") {
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://github.com/pasukistudio/elyra-vita")!) {
                Label("Projekt auf GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
            }

            Link(destination: URL(string: "https://github.com/pasukistudio/elyra-vita/issues")!) {
                Label("Fehler auf GitHub melden", systemImage: "ladybug")
            }
        }
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
        profile.updatedAt = Date()

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
