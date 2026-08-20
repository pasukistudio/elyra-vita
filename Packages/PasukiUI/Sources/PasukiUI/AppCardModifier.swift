import SwiftUI

// MARK: - AppCard

/// Einheitliches Kartendesign für SwiftUI-Inhalte.
public extension View {

    /// Wendet eine adaptive, abgerundete Karte auf den Inhalt an.
    func appCard(
        padding: EdgeInsets = EdgeInsets(
            top: 20,
            leading: 20,
            bottom: 20,
            trailing: 20
        )
    ) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                pasukiCardBackground,
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.primary.opacity(0.07), lineWidth: 1)
            }
    }
}

// MARK: - Plattformfarben

private var pasukiCardBackground: Color {
#if os(iOS)
    Color(uiColor: .secondarySystemGroupedBackground)
#elseif os(macOS)
    Color(nsColor: .windowBackgroundColor)
#else
    Color.secondary.opacity(0.12)
#endif
}
