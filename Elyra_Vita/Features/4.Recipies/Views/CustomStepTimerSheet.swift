import SwiftUI

struct CustomStepTimerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onStart: (Int) -> Void
    @State private var minutes = "5"

    var body: some View {
        NavigationStack {
            Form {
                Section("Eigener Schritt-Timer") {
                    TextField("Minuten", text: $minutes)
                        .keyboardType(.numberPad)
                    Text("Der Timer gilt nur für den aktuell angezeigten Zubereitungsschritt.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Timer einstellen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Starten") {
                        let value = Int(minutes) ?? 0
                        guard value > 0 else { return }
                        onStart(value * 60)
                        dismiss()
                    }
                    .disabled((Int(minutes) ?? 0) <= 0)
                }
            }
        }
    }
}
