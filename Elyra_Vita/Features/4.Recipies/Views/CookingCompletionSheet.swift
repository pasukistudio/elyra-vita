import SwiftUI

struct CookingCompletionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let defaultServings: Int
    let onComplete: (Double) -> Void
    @State private var portionsText: String

    init(defaultServings: Int, onComplete: @escaping (Double) -> Void) {
        self.defaultServings = defaultServings
        self.onComplete = onComplete
        _portionsText = State(initialValue: "1")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Kochen abschließen") {
                    Text("Wie viele Portionen hast du gegessen?")
                    TextField("Portionen", text: $portionsText)
                        .keyboardType(.decimalPad)
                    Text("Das Rezept ist für \(defaultServings) Portion(en) angelegt.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Fertig gekocht")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let portions = Double(portionsText.replacingOccurrences(of: ",", with: ".")) ?? 1
                        onComplete(max(portions, 0.1))
                        dismiss()
                    }
                }
            }
        }
    }
}
