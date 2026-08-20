import SwiftUI

// MARK: - AppBackground

public extension View {

    /// Setzt den standardisierten gruppierten App-Hintergrund.
    func appBackground() -> some View {
        ZStack {
            pasukiAppBackgroundColor
                .ignoresSafeArea()

            self
        }
    }
}

// MARK: - Plattformfarben

private var pasukiAppBackgroundColor: Color {
#if os(iOS)
    Color(uiColor: .systemGroupedBackground)
#elseif os(macOS)
    Color(nsColor: .windowBackgroundColor)
#else
    Color.secondary.opacity(0.08)
#endif
}
