import SwiftUI
import SwiftData
import PasukiUI

struct HabitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.updatedAt, order: .reverse) private var habits: [Habit]
    @Query private var completions: [HabitCompletion]
    @Binding var showingNewHabit: Bool
    @State private var editingHabit: Habit?
    @State private var deletingHabit: Habit?
    @State private var saveErrorMessage: String?
    @State private var notificationMessage: String?

    init(showingNewHabit: Binding<Bool>) {
        _showingNewHabit = showingNewHabit
        let calendar = Calendar.current
        let monthStart = calendar.dateInterval(of: .month, for: .now)?.start ?? .now
        let rangeStart = calendar.date(byAdding: .month, value: -2, to: monthStart) ?? monthStart
        let rangeEnd = calendar.date(byAdding: .month, value: 3, to: monthStart) ?? .now
        _completions = Query(filter: #Predicate<HabitCompletion> { completion in
            completion.day >= rangeStart && completion.day < rangeEnd
        })
    }

    private var activeHabits: [Habit] { habits.filter { !$0.isArchived } }
    private var selectedDate: Date { Date() }
    private var completionDaysByHabit: [UUID: [Date]] {
        Dictionary(grouping: completions, by: \.habitID).mapValues { records in
            Array(Set(records.map { Calendar.current.startOfDay(for: $0.day) }))
        }
    }
    private func completionDays(for habit: Habit) -> [Date] { completionDaysByHabit[habit.id] ?? [] }
    private var dueHabits: [Habit] { activeHabits.filter { $0.isDue(on: selectedDate, completionDays: completionDays(for: $0)) } }
    private var upcomingHabits: [Habit] {
        let dueHabitIDs = Set(dueHabits.map { $0.id })
        return activeHabits.filter { !dueHabitIDs.contains($0.id) }
    }
    private var progressHabits: [Habit] {
        activeHabits.filter { habit in
            switch habit.recurrence {
            case .daily, .weekly, .monthly:
                return true
            case .selectedDays:
                return habit.isDue(on: selectedDate, completionDays: completionDays(for: habit))
            }
        }
    }
    private var progressTotal: Int {
        progressHabits.reduce(0) { total, habit in
            total + ((habit.recurrence == .weekly || habit.recurrence == .monthly) ? habit.targetCount : 1)
        }
    }
    private var completedCount: Int {
        progressHabits.reduce(0) { total, habit in
            switch habit.recurrence {
            case .weekly, .monthly:
                let component: Calendar.Component = habit.recurrence == .weekly ? .weekOfYear : .month
                guard let interval = Calendar.current.dateInterval(of: component, for: selectedDate),
                      let periodEnd = Calendar.current.date(byAdding: component, value: 1, to: interval.start)
                else { return total }
                let count = completionDays(for: habit).filter { $0 >= interval.start && $0 < periodEnd }.count
                return total + min(count, habit.targetCount)
            case .daily, .selectedDays:
                return total + (isCompleted(habit) ? 1 : 0)
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                progressCard
                dueSection
                upcomingSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Gewohnheiten")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingNewHabit = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Neue Gewohnheit")
            }
        }
        .sheet(isPresented: $showingNewHabit) { HabitEditorView().presentationDetents([.medium, .large]) }
        .sheet(item: $editingHabit) { HabitEditorView(habit: $0).presentationDetents([.medium, .large]) }
        .alert("Gewohnheit löschen?", isPresented: deletingAlert, presenting: deletingHabit) { habit in
            Button("Löschen", role: .destructive) {
                modelContext.delete(habit)
                if PersistenceErrorReporter.save(modelContext, operation: "Habit löschen") {
                    deletingHabit = nil
                }
            }
            Button("Abbrechen", role: .cancel) { deletingHabit = nil }
        } message: { habit in Text("\"\(habit.name)\" wird dauerhaft entfernt.") }
        .alert("Änderung konnte nicht gespeichert werden", isPresented: saveErrorPresented) {
            Button("OK", role: .cancel) { saveErrorMessage = nil }
        } message: {
            Text(saveErrorMessage ?? "Bitte versuche es erneut.")
        }
        .alert("Erinnerungen", isPresented: notificationPresented) {
            Button("OK", role: .cancel) { notificationMessage = nil }
        } message: {
            Text(notificationMessage ?? "")
        }
        .task {
            deduplicateCompletions()
            await rescheduleNotifications()
        }
        .onChange(of: habits.map(\.updatedAt)) { _, _ in Task { await rescheduleNotifications() } }
        .onChange(of: completions.map(\.updatedAt)) { _, _ in Task { await rescheduleNotifications() } }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Label("Heute", systemImage: "sun.max.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text(completedCount == progressTotal && progressTotal > 0 ? "Alles erledigt" : "Dein Tagesfortschritt")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(completedCount)/\(progressTotal)").font(.title3.weight(.bold)).foregroundStyle(.green)
            }
            SwiftUI.ProgressView(value: progressTotal == 0 ? 0 : Double(completedCount), total: Double(max(progressTotal, 1))).tint(.green)
        }
        .padding(18).background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 12, y: 5)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sun.max.fill").font(.system(size: 28)).foregroundStyle(.orange)
            Text("Heute ist nichts fällig").font(.headline)
            Text(activeHabits.isEmpty ? "Lege deine erste Gewohnheit an." : "Genieße den freien Tag oder blättere zu einem anderen Datum.")
                .font(.subheadline).multilineTextAlignment(.center).foregroundStyle(.secondary)
            if activeHabits.isEmpty { Button("Gewohnheit anlegen") { showingNewHabit = true }.buttonStyle(.borderedProminent) }
        }.frame(maxWidth: .infinity).padding(.vertical, 28)
    }

    @ViewBuilder
    private var dueSection: some View {
        if dueHabits.isEmpty {
            emptyState
        } else {
            sectionTitle("Heute fällig", detail: "\(completedCount) von \(progressTotal) erledigt")
            habitList(dueHabits)
        }
    }

    @ViewBuilder
    private var upcomingSection: some View {
        if !upcomingHabits.isEmpty {
            sectionTitle("Weitere Gewohnheiten", detail: nil)
            habitList(upcomingHabits)
        }
    }

    private func sectionTitle(_ title: String, detail: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.weight(.bold)); Spacer()
            if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
        }
    }

    private func habitList(_ habits: [Habit]) -> some View {
        VStack(spacing: 10) {
            ForEach(habits) { habit in
                habitCard(habit)
            }
        }
    }

    private func habitCard(_ habit: Habit) -> some View {
        let due = habit.isDue(on: selectedDate, completionDays: completionDays(for: habit))
        let completed = isCompleted(habit)
        return HStack(spacing: 14) {
            Button { toggle(habit, completed: completed) } label: {
                Image(systemName: completed ? "checkmark.circle.fill" : "circle").font(.system(size: 28))
                    .foregroundStyle(completed ? AnyShapeStyle(.green) : (due ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tertiary)))
            }.buttonStyle(.plain).disabled(!due)
            VStack(alignment: .leading, spacing: 7) {
                Text(habit.name).font(.headline).strikethrough(completed).foregroundStyle(completed ? .secondary : .primary)
                HStack(spacing: 6) {
                    Label(habit.recurrenceText, systemImage: "repeat"); Text("·"); Label(habit.reminderTimeText, systemImage: "bell")
                }.font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Circle().fill(due ? Color.orange.opacity(0.14) : Color.secondary.opacity(0.10)).frame(width: 34, height: 34)
                .overlay { Image(systemName: due ? "bell.fill" : "calendar").font(.caption).foregroundStyle(due ? .orange : .secondary) }
        }
        .padding(16).background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(Rectangle()).contextMenu {
            Button("Bearbeiten", systemImage: "pencil") { editingHabit = habit }
            Button("Löschen", systemImage: "trash", role: .destructive) { deletingHabit = habit }
        }
    }

    private func isCompleted(_ habit: Habit) -> Bool {
        completions.contains { $0.habitID == habit.id && Calendar.current.isDate($0.day, inSameDayAs: selectedDate) }
    }

    private func toggle(_ habit: Habit, completed: Bool) {
        if let completion = completions.first(where: { $0.habitID == habit.id && Calendar.current.isDate($0.day, inSameDayAs: selectedDate) }) {
            modelContext.delete(completion)
        } else if !completed { modelContext.insert(HabitCompletion(habitID: habit.id, day: selectedDate)) }
        PersistenceErrorReporter.save(modelContext, operation: "Habit-Abschluss ändern") { message in
            saveErrorMessage = message
        }
    }

    private func deduplicateCompletions() {
        var seen = Set<String>()
        var removedAny = false
        for completion in completions.sorted(by: { $0.completedAt < $1.completedAt }) {
            let day = Calendar.current.startOfDay(for: completion.day).timeIntervalSince1970
            let key = "\(completion.habitID.uuidString)-\(day)"
            if !seen.insert(key).inserted {
                modelContext.delete(completion)
                removedAny = true
            }
        }
        if removedAny {
            PersistenceErrorReporter.save(modelContext, operation: "Doppelte Habit-Abschlüsse bereinigen")
        }
    }

    private var deletingAlert: Binding<Bool> { Binding(get: { deletingHabit != nil }, set: { if !$0 { deletingHabit = nil } }) }

    private var saveErrorPresented: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )
    }

    private var notificationPresented: Binding<Bool> {
        Binding(
            get: { notificationMessage != nil },
            set: { if !$0 { notificationMessage = nil } }
        )
    }

    private func rescheduleNotifications() async {
        guard await HabitNotificationService.requestPermission() else {
            notificationMessage = "Benachrichtigungen sind deaktiviert. Aktiviere sie in den iPhone-Einstellungen, damit Habit-Erinnerungen angezeigt werden."
            return
        }
        let result = await HabitNotificationService.schedule(for: activeHabits, completions: completions)
        if result.failedCount > 0 {
            notificationMessage = "\(result.failedCount) Erinnerung(en) konnten nicht geplant werden."
        } else if result.skippedCount > 0 {
            notificationMessage = "Es konnten nur \(result.scheduledCount) Erinnerungen geplant werden, da iOS maximal 64 ausstehende Benachrichtigungen zulässt."
        }
    }
}
