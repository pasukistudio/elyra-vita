import SwiftUI
import PasukiUI

// MARK: - DatePickerView

/// Elyra-Vita-Konfiguration des wiederverwendbaren PasukiUI-Dateipickers.
///
/// Die App entscheidet hier über Sprache und Sheet-Größe; die technische
/// Picker-Struktur liegt zentral im UI-Paket und kann später von Elyra Budget
/// wiederverwendet werden.
struct DatePickerView: View {

    // MARK: - Eingaben

    @Binding var selectedDate: Date

    // MARK: - Ansicht

    var body: some View {
        PasukiDatePickerSheet(
            selectedDate: $selectedDate,
            title: "Datum auswählen",
            confirmationTitle: "Fertig"
        )
    }
}
