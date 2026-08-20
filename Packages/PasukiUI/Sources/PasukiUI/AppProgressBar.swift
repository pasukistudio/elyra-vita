import SwiftUI

// MARK: - AppProgressBar

/// Eine kompakte, wiederverwendbare Fortschrittsanzeige für SwiftUI-Apps.
///
/// `progress` wird intern auf den gültigen Bereich von 0 bis 1 begrenzt.
/// Dadurch kann die Komponente auch mit Rohwerten aus Berechnungen verwendet werden.
public struct AppProgressBar: View {

    // MARK: - Eingaben

    /// Fortschritt zwischen 0 und 1.
    public let progress: Double

    /// Farbe des gefüllten Fortschrittsbereichs.
    public let color: Color

    /// Höhe der Leiste.
    public let height: CGFloat

    // MARK: - Initialisierung

    public init(
        progress: Double,
        color: Color,
        height: CGFloat = 10
    ) {
        self.progress = progress
        self.color = color
        self.height = height
    }

    // MARK: - Ansicht

    public var body: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.18))
            .frame(height: height)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(color)
                    .frame(maxWidth: .infinity)
                    .scaleEffect(
                        x: clampedProgress,
                        y: 1,
                        anchor: .leading
                    )
            }
            .animation(.easeInOut, value: clampedProgress)
            .accessibilityValue("\(Int(clampedProgress * 100)) Prozent")
    }

    // MARK: - Berechnete Werte

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }
}
