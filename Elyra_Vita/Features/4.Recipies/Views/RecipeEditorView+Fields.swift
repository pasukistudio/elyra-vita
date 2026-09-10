import SwiftUI

extension RecipeEditorView {
    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && ingredients.contains { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            && steps.contains { !$0.instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var errorPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: {
            if !$0 {
                errorMessage = nil
            }
        })
    }

    func stepRow(step: Binding<StepDraft>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Text(String(step.wrappedValue.position + 1))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                TextField("Zubereitungsschritt", text: step.instruction, axis: .vertical)
            }
            Stepper(
                step.wrappedValue.durationSeconds == 0
                    ? "Kein Schritt-Timer"
                    : "Schritt-Timer: \(step.wrappedValue.durationSeconds / 60) Min.",
                value: Binding(
                    get: { step.wrappedValue.durationSeconds / 60 },
                    set: { step.wrappedValue.durationSeconds = max(0, $0 * 60) }
                ),
                in: 0 ... 180
            )
            .font(.caption)
        }
    }

    func nutrientTextField(_ title: String, text: Binding<String>, unit: String) -> some View {
        HStack {
            TextField(title, text: text)
                .keyboardType(.decimalPad)
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }
}
