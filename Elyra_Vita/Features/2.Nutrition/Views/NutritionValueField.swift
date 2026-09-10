import SwiftUI

struct NutritionValueField: View {
    let title: String
    @Binding var text: String
    let unit: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            TextField("", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 72)
                .accessibilityLabel(title)
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }
}
