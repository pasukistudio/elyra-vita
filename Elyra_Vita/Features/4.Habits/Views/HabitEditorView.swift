import SwiftUI
import SwiftData

struct HabitEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let habit: Habit?
    @State private var name: String
    @State private var note: String
    @State private var recurrence: HabitRecurrence
    @State private var weekdaysMask: Int
    @State private var targetCount: Int
    @State private var preset: HabitTimePreset
    @State private var reminderTime: Date
    @State private var saveErrorMessage: String?

    init(habit: Habit? = nil) {
        self.habit = habit
        _name = State(initialValue: habit?.name ?? "")
        _note = State(initialValue: habit?.note ?? "")
        _recurrence = State(initialValue: habit?.recurrence ?? .daily)
        _weekdaysMask = State(initialValue: habit?.selectedWeekdaysMask ?? 0b0000110)
        _targetCount = State(initialValue: habit?.targetCount ?? 1)
        _preset = State(initialValue: habit?.timePreset ?? .morning)
        _reminderTime = State(initialValue: Calendar.current.date(from: habit?.reminderDateComponents ?? HabitTimePreset.morning.defaultComponents) ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Gewohnheit") {
                    TextField("Name", text: $name)
                    TextField("Notiz (optional)", text: $note, axis: .vertical)
                }
                Section("Wiederholung") {
                    Picker("Intervall", selection: $recurrence) {
                        ForEach(HabitRecurrence.allCases) { Text($0.title).tag($0) }
                    }
                    if recurrence == .selectedDays {
                        weekdayPicker
                    } else if recurrence == .weekly || recurrence == .monthly {
                        Picker("Häufigkeit", selection: $targetCount) {
                            ForEach(1...(recurrence == .weekly ? 7 : 31), id: \.self) { count in
                                Text("\(count)× pro \(recurrence == .weekly ? "Woche" : "Monat")").tag(count)
                            }
                        }
                    }
                    Text(recurrenceDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Erinnerung") {
                    Picker("Zeitpunkt", selection: $preset) {
                        ForEach(HabitTimePreset.allCases) { Text($0.title).tag($0) }
                    }
                    if preset == .custom {
                        DatePicker("Uhrzeit", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    } else {
                        Text(reminderTime.formatted(date: .omitted, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(habit == nil ? "Neue Gewohnheit" : "Gewohnheit bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (recurrence == .selectedDays && weekdaysMask == 0))
                }
            }
            .onChange(of: preset) { _, newValue in
                if newValue != .custom { reminderTime = Calendar.current.date(from: newValue.defaultComponents) ?? reminderTime }
            }
            .alert("Speichern fehlgeschlagen", isPresented: saveErrorPresented) {
                Button("OK", role: .cancel) { saveErrorMessage = nil }
            } message: {
                Text(saveErrorMessage ?? "Die Gewohnheit konnte nicht gespeichert werden.")
            }
        }
    }

    private var weekdayPicker: some View {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        return HStack {
            ForEach(1...7, id: \.self) { weekday in
                let selected = weekdaysMask & (1 << (weekday - 1)) != 0
                Button { weekdaysMask ^= 1 << (weekday - 1) } label: {
                    Text(symbols[weekday - 1])
                        .font(.caption.weight(.semibold))
                        .frame(width: 34, height: 34)
                        .foregroundStyle(selected ? .white : .primary)
                        .background(selected ? Color.accentColor : Color.secondary.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var recurrenceDescription: String {
        switch recurrence {
        case .daily: return "Jeden Tag"
        case .weekly: return "An beliebigen Tagen, bis zu \(targetCount)× pro Woche"
        case .monthly: return "An beliebigen Tagen, bis zu \(targetCount)× pro Monat"
        case .selectedDays: return weekdaysMask == 0 ? "Bitte mindestens einen Tag auswählen" : "Nur an den markierten Tagen"
        }
    }

    private func save() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let hour = components.hour ?? 8
        let minute = components.minute ?? 0
        if let habit {
            habit.update(name: name, note: note, recurrence: recurrence, weekdaysMask: weekdaysMask, anchorDate: .now, targetCount: targetCount, preset: preset, hour: hour, minute: minute)
        } else {
            let newHabit = Habit(name: name, recurrence: recurrence, anchorDate: .now)
            newHabit.update(name: name, note: note, recurrence: recurrence, weekdaysMask: weekdaysMask, anchorDate: .now, targetCount: targetCount, preset: preset, hour: hour, minute: minute)
            modelContext.insert(newHabit)
        }
        do {
            try modelContext.save()
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }

    private var saveErrorPresented: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )
    }
}
