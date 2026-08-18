import SwiftUI

struct DatePickerView: View {
    @Environment(\.dismiss)
    private var dismiss

    @Binding var selectedDate: Date

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .onChange(of: selectedDate) {
                    dismiss()
                }
            }
            .toolbar {
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .topBarLeading) {
                        Text("Datum auswählen")
                            .font(.headline)
                            .fixedSize(
                                horizontal: true,
                                vertical: false
                            )
                            .allowsHitTesting(false)
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarLeading) {
                        Text("Datum auswählen")
                            .font(.headline)
                            .fixedSize(
                                horizontal: true,
                                vertical: false
                            )
                            .allowsHitTesting(false)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
    }
}
