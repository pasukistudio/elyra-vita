import SwiftUI

private struct ElyraAccentColorKey: EnvironmentKey {
    static let defaultValue: Color = .teal
}

extension EnvironmentValues {
    var elyraAccentColor: Color {
        get { self[ElyraAccentColorKey.self] }
        set { self[ElyraAccentColorKey.self] = newValue }
    }
}

/// Einheitlicher Floating-Action-Button für primäre Hinzufügen-Aktionen.
struct ElyraFloatingActionButton: View {
    @Environment(\.elyraAccentColor) private var accentColor
    private let action: () -> Void
    private let accessibilityLabel: String

    init(
        accessibilityLabel: String = "Hinzufügen",
        action: @escaping () -> Void
    ) {
        self.action = action
        self.accessibilityLabel = accessibilityLabel
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(accentColor, in: Circle())
                .shadow(color: .black.opacity(0.16), radius: 10, y: 5)
        }
        .accessibilityLabel(accessibilityLabel)
    }
}
