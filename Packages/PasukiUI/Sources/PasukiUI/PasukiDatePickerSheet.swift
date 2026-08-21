import SwiftUI

// MARK: - PasukiDatePickerSheet

/// Standardisiertes Sheet für eine einzelne Datumsauswahl.
///
/// Fachliche Regeln wie Monatsauswahl, erlaubte Datumsbereiche oder eine
/// spezielle Kalenderdarstellung bleiben beim aufrufenden Produkt.
public struct PasukiDatePickerSheet: View {

    // MARK: - Abhängigkeiten

    @Environment(\.dismiss) private var dismiss

    // MARK: - Eingaben

    @Binding public var selectedDate: Date
    public let title: String
    public let confirmationTitle: String
    public let dismissOnSelection: Bool

    // MARK: - Initialisierung

    public init(
        selectedDate: Binding<Date>,
        title: String = "Select date",
        confirmationTitle: String = "Done",
        dismissOnSelection: Bool = true
    ) {
        self._selectedDate = selectedDate
        self.title = title
        self.confirmationTitle = confirmationTitle
        self.dismissOnSelection = dismissOnSelection
    }

    // MARK: - Ansicht

    public var body: some View {
        NavigationStack {
            DatePicker(
                "",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .onChange(of: selectedDate, perform: { _ in
                guard dismissOnSelection else { return }
                dismiss()
            })
            .toolbar {
                titleToolbarItem

                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmationTitle) {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var titleToolbarItem: some ToolbarContent {
        ToolbarItem(placement: pasukiLeadingToolbarPlacement) {
            Text(title)
                .font(.headline)
                .fixedSize(horizontal: true, vertical: false)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Plattformlayout

    private var pasukiLeadingToolbarPlacement: ToolbarItemPlacement {
#if os(iOS)
        .topBarLeading
#else
        .navigation
#endif
    }
}
