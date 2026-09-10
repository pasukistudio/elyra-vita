import SwiftUI

struct RecipeFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var ingredientFilter: String
    @Binding var matchAllIngredients: Bool
    @Binding var maximumMinutes: Int?

    var body: some View {
        NavigationStack {
            Form {
                Section("Gewünschte Zutaten") {
                    TextField("Zum Beispiel: Nudeln, Erbsen", text: $ingredientFilter)
                    Picker("Übereinstimmung", selection: $matchAllIngredients) {
                        Text("Eine der Zutaten").tag(false)
                        Text("Alle Zutaten").tag(true)
                    }
                    .pickerStyle(.segmented)
                    Text("Mehrere Zutaten mit Komma trennen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Weitere Filter") {
                    Picker("Maximale Zeit", selection: $maximumMinutes) {
                        Text("Beliebig").tag(Int?.none)
                        Text("30 Min.").tag(Int?.some(30))
                        Text("60 Min.").tag(Int?.some(60))
                    }
                    Button("Alle Filter zurücksetzen", role: .destructive) {
                        ingredientFilter = ""
                        matchAllIngredients = false
                        maximumMinutes = nil
                    }
                }
            }
            .navigationTitle("Rezepte filtern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
