import SwiftUI
import PasukiUI

// MARK: - App-Adapter

/// Elyra-Vita-Adapter für die generische PasukiUI-Datumsnavigation.
///
/// Die Typalias hält den bestehenden App-Code schlank. Die Tagesbegriffe
/// werden im Toolbar-Aufrufer über `PasukiDateNavigationLabels` gesetzt.
typealias DateNavigationControl = PasukiDateNavigationControl

#Preview("Datumsnavigation") {
    DateNavigationControl(
        title: "September 2026",
        labels: .init(
            previous: "Vorheriger Tag",
            selection: "Datum auswählen",
            next: "Nächster Tag"
        ),
        onPrevious: {},
        onSelect: {},
        onNext: {}
    )
    .padding()
}
