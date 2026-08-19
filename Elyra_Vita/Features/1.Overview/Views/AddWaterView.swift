import SwiftUI

struct AddWaterView: View {

    var body: some View {
        List {
            Section{
                waterFastAdd
            }header: {
                Text("Schnell hinzufügen")
            }
        }
    }

    private var waterFastAdd: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                quickAddButton(title: "+ 250 ml")
                quickAddButton(title: "+ 500 ml")
            }

            HStack(spacing: 12) {
                quickAddButton(title: "+ 750 ml")
                quickAddButton(title: "+ 1.000 ml")
            }
        }
        .padding(.vertical, 8)
    }

    /// Baut einen einheitlich formatierten Schnell-hinzufügen-Button.
    private func quickAddButton(title: String) -> some View {
        Button {
            // Die eigentliche Wasserbuchung wird später ergänzt.
        } label: {
            Label(title, systemImage: "drop.fill")
                .font(.title3.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .background(
            Color.accentColor.opacity(0.18),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
    }
}

#Preview("AddWaterView") {
    AddWaterView()
}
