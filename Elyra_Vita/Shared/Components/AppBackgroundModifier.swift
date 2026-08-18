import SwiftUI

private struct AppBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            content
        }
    }
}

extension View {
    func appBackground() -> some View {
        modifier(AppBackgroundModifier())
    }
}
