import SwiftUI
import PasukiUI

// MARK: - PresetColorSelectionView

/// Wählt eine Elyra-Vita-Presetfarbe oder einen eigenen Farbwert aus.
struct PresetColorSelectionView: View {
    // MARK: - Eingaben und Aktionen

    /// Der aktuell gespeicherte Hex-Wert der Auswahl.
    @Binding var selection: String

    /// Beschriftung oberhalb der Farbauswahl.
    var title: LocalizedStringResource = "Icon-Farbe"

    /// Wird ausgefuehrt, wenn ein festes Preset ausgewaehlt wurde.
    var onPresetSelected: ((ColorPreset) -> Void)? = nil

    /// Wird ausgefuehrt, wenn der Benutzer eine eigene Farbe waehlt.
    var onCustomColorChanged: ((String) -> Void)? = nil

    /// Optionaler gemeinsamer Pro-Zugriff. Ohne Service bleibt die bisherige
    /// freie Auswahl aktiv, bis die App ihren StoreKit-Service einspeist.
    var proAccess: (any PasukiProAccess)? = nil

    /// Anzahl und Verhalten der Spalten im Farbraster.
    var columns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: 8),
        count: 5
    )

    // MARK: - Abgeleitete Werte

    /// Die aus dem Hex-Wert erzeugte SwiftUI-Farbe.
    private var selectedColor: Color {
        Color(hexString: selection)
    }

    /// Binding fuer den nativen ColorPicker.
    /// Der ColorPicker arbeitet mit Color, gespeichert wird aber weiterhin Hex.
    private var customColorBinding: Binding<Color> {
        Binding(
            get: { selectedColor },
            set: { newColor in
                if let hex = newColor.toHex() {
                    selection = hex
                    onCustomColorChanged?(hex)
                }
            }
        )
    }

    // MARK: - Ansicht

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(ColorPreset.allCases) { preset in
                    presetButton(preset)
                }
            }
            Divider()
            ColorPicker(
                selection: customColorBinding,
                supportsOpacity: false
            ) {
                Label("Eigene Farbe", systemImage: "paintpalette")
            }
            .disabled(!customColorIsAvailable)
            .padding(.trailing, 17)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Einzelnes Preset

    private var customColorIsAvailable: Bool {
        guard let proAccess else { return true }
        return PasukiAccentColorSelection.custom(hex: selection)
            .isAvailable(for: proAccess)
    }

    /// Baut einen runden Button fuer eine Preset-Farbe.
    private func presetButton(_ preset: ColorPreset) -> some View {
        let isSelected = selection.caseInsensitiveCompare(preset.hex) == .orderedSame

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selection = preset.hex
                onPresetSelected?(preset)
            }
        } label: {
            ZStack {
                Circle()
                    .fill(preset.color)
                    .frame(width: 36, height: 36)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(preset.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
