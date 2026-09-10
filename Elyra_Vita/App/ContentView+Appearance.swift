import PasukiUI
import SwiftUI

extension ContentView {
    /// Übersetzt die gespeicherte Auswahl in ein SwiftUI-Farbschema.
    var preferredColorScheme: ColorScheme? {
        guard let rawValue = userSettings.first?.appearanceRawValue,
              let appearance = AppAppearance(rawValue: rawValue)
        else {
            return nil
        }

        return appearance.colorScheme
    }

    /// Ermittelt die Preset- oder eigene Akzentfarbe des Profils.
    var selectedAccentColor: Color {
        guard let settings = userSettings.first else {
            return ColorPreset.blue.color
        }

        let accentColor = AppAccentColor(rawValue: settings.accentColorRawValue)
        if accentColor == .custom {
            return Color(hexString: settings.customAccentHex)
        }

        return accentColor.color ?? ColorPreset.blue.color
    }
}
