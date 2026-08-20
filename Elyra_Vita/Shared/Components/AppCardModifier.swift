import SwiftUI

// MARK: - Gemeinsames Kartendesign

/// Ein wiederverwendbarer Modifier für alle Karten innerhalb der App.
///
/// Dieser Modifier kümmert sich nur um das Erscheinungsbild einer Karte.
/// Der eigentliche Inhalt, zum Beispiel Kalorien- oder Gewichtsdaten,
/// bleibt in der jeweiligen Karte bestehen.
private struct AppCardModifier: ViewModifier {

    // MARK: - Eingaben

    /// Innenabstand der Karte. Er kann pro Karte angepasst werden,
    /// während das gemeinsame Erscheinungsbild erhalten bleibt.
    let padding: EdgeInsets

    // MARK: - Kartenaufbau

    /// Wendet das gemeinsame Kartendesign auf die übergebene View an.
    ///
    /// `content` ist die View, auf der später `.appCard()` verwendet wird.
    /// Bei der CalorieSummaryCard ist das beispielsweise das äußere VStack.
    func body(content: Content) -> some View {
        // Die Modifier-Kette beginnt mit `content`.
        // Dadurch weiß SwiftUI, auf welche View die folgenden
        // Gestaltungsschritte angewendet werden sollen.
        content
            // Innenabstand zwischen dem Karteninhalt und dem Kartenrand.
            // Texte und andere Elemente kleben dadurch nicht am Rand.
            .padding(padding)
            // Die Karte darf die gesamte verfügbare Breite einnehmen.
            // Der Inhalt bleibt dabei links ausgerichtet.
            .frame(maxWidth: .infinity, alignment: .leading)
            // Zeichnet den Hintergrund hinter dem Karteninhalt.
            // Die Systemfarbe passt sich an Light- und Dark-Mode an.
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(
                    // Bestimmt, wie stark die Kartenecken abgerundet sind.
                    cornerRadius: 24,
                    // Erzeugt eine weichere, Apple-typische Rundung.
                    style: .continuous
                )
            )
            // Legt eine zusätzliche View über die fertige Karte.
            // Hier verwenden wir das Overlay für den Außenrahmen.
            .overlay {
                RoundedRectangle(
                    cornerRadius: 24,
                    style: .continuous
                )
                // Zeichnet nur den Rand der Form, nicht ihre Innenfläche.
                .stroke(
                    // Die geringe Transparenz macht den Rahmen dezent.
                    .primary.opacity(0.07),
                    lineWidth: 1
                )
            }
    }
}

// MARK: - Bequeme Verwendung

/// Macht das Kartendesign als einfachen View-Modifier verfügbar.
///
/// Dadurch genügt in den einzelnen Karten `.appCard()`,
/// statt den vollständigen `AppCardModifier` aufzurufen.
extension View {
    /// Wendet das einheitliche Kartendesign auf eine View an.
    func appCard(
        padding: EdgeInsets = EdgeInsets(
            top: 20,
            leading: 20,
            bottom: 20,
            trailing: 20
        )
    ) -> some View {
        modifier(AppCardModifier(padding: padding))
    }
}
