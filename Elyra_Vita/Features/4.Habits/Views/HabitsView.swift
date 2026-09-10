import PasukiUI
import SwiftData
import SwiftUI
import UserNotifications

struct HabitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.updatedAt, order: .reverse) private var habits: [Habit]
    @Query var completions: [HabitCompletion]
    @Binding var showingNewHabit: Bool
    @State private var editingHabit: Habit?
    @State var deletingHabit: Habit?
    @State var saveErrorMessage: String?
    @State var notificationMessage: String?

    init(showingNewHabit: Binding<Bool>) {
        _showingNewHabit = showingNewHabit
        _completions = Query(sort: \HabitCompletion.day, order: .forward)
    }

    var activeHabits: [Habit] {
        habits.filter { !$0.isArchived }
    }

    private var selectedDate: Date {
        Date()
    }

    private var dailyHabits: [Habit] {
        activeHabits.filter { $0.recurrence == .daily }
    }

    private var weeklyHabits: [Habit] {
        activeHabits.filter { $0.recurrence == .weekly || $0.recurrence == .selectedDays }
    }

    private var monthlyHabits: [Habit] {
        activeHabits.filter { $0.recurrence == .monthly }
    }

    private var completionDaysByHabit: [UUID: [Date]] {
        Dictionary(grouping: completions, by: \.habitID).mapValues { records in
            Array(Set(records.map { Calendar.current.startOfDay(for: $0.day) }))
        }
    }

    private func completionDays(for habit: Habit) -> [Date] {
        completionDaysByHabit[habit.id] ?? []
    }

    private var progressHabits: [Habit] {
        activeHabits.filter { habit in
            switch habit.recurrence {
            case .daily:
                return true
            case .selectedDays:
                return habit.isDue(on: selectedDate, completionDays: completionDays(for: habit))
            case .weekly, .monthly:
                // Wochen- und Monatsziele sind keine Tagesaufgaben. Sie
                // dürfen deshalb den Tagesfortschritt nicht vergrößern.
                return false
            }
        }
    }

    private var progressTotal: Int {
        progressHabits.count
    }

    private var completedCount: Int {
        progressHabits.reduce(0) { total, habit in
            total + (isCompleted(habit) ? 1 : 0)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                progressCard
                if activeHabits.isEmpty {
                    emptyState
                } else {
                    habitSection("Täglich", systemImage: "sun.max.fill", habits: dailyHabits)
                    habitSection("Wöchentlich", systemImage: "calendar.badge.clock", habits: weeklyHabits)
                    habitSection("Monatlich", systemImage: "calendar", habits: monthlyHabits)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Gewohnheiten")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingNewHabit) { HabitEditorView().presentationDetents([.medium, .large]) }
        .sheet(item: $editingHabit) { HabitEditorView(habit: $0).presentationDetents([.medium, .large]) }
        .alert("Gewohnheit löschen?", isPresented: deletingAlert, presenting: deletingHabit) { habit in
            Button("Löschen", role: .destructive) {
                do {
                    let habitID = habit.id
                    let descriptor = FetchDescriptor<HabitCompletion>(predicate: #Predicate { completion in
                        completion.habitID == habitID
                    })
                    for completion in try modelContext.fetch(descriptor) {
                        modelContext.delete(completion)
                    }
                    modelContext.delete(habit)
                    if PersistenceErrorReporter.save(modelContext, operation: "Habit löschen") {
                        deletingHabit = nil
                    }
                } catch {
                    saveErrorMessage = error.localizedDescription
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
                    Text(
                        completedCount == progressTotal && progressTotal > 0
                            ? "Alles erledigt"
                            : "Dein Tagesfortschritt"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(completedCount)/\(progressTotal)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.green)
            }
            SwiftUI.ProgressView(
                value: progressTotal == 0 ? 0 : Double(completedCount),
                total: Double(max(progressTotal, 1))
            )
            .tint(.green)
        }
        .padding(18)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .shadow(color: .black.opacity(0.04), radius: 12, y: 5)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sun.max.fill").font(.system(size: 28)).foregroundStyle(.orange)
            Text("Heute ist nichts fällig").font(.headline)
            Text("Lege deine erste Gewohnheit an.")
                .font(.subheadline).multilineTextAlignment(.center).foregroundStyle(.secondary)
            if activeHabits.isEmpty {
                Button("Gewohnheit anlegen") { showingNewHabit = true }
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    @ViewBuilder
    private func habitSection(_ title: String, systemImage: String, habits: [Habit]) -> some View {
        if !habits.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .foregroundStyle(.orange)
                    Text(title)
                        .font(.title3.weight(.bold))
                    Spacer()
                    Text("\(habits.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                habitList(habits)
            }
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
        HabitCardView(
            habit: habit,
            selectedDate: selectedDate,
            completionDays: completionDays(for: habit),
            isCompleted: isCompleted(habit),
            onToggle: { toggle(habit, completed: isCompleted(habit)) },
            onEdit: { editingHabit = habit },
            onDelete: { deletingHabit = habit }
        )
    }

    private func isCompleted(_ habit: Habit) -> Bool {
        completions.contains { $0.habitID == habit.id && Calendar.current.isDate($0.day, inSameDayAs: selectedDate) }
    }

    private func toggle(_ habit: Habit, completed: Bool) {
        let matchingCompletions = completions.filter {
            $0.habitID == habit.id && Calendar.current.isDate($0.day, inSameDayAs: selectedDate)
        }
        if let completion = matchingCompletions.first {
            modelContext.delete(completion)
            for duplicate in matchingCompletions.dropFirst() {
                modelContext.delete(duplicate)
            }
        } else if !completed {
            modelContext.insert(HabitCompletion(habitID: habit.id, day: selectedDate))
        }
        PersistenceErrorReporter.save(modelContext, operation: "Habit-Abschluss ändern") { message in
            saveErrorMessage = message
        }
    }

    private func deduplicateCompletions() {
        do {
            if try HabitCompletionStore.removeDuplicates(in: modelContext) {
                PersistenceErrorReporter.save(modelContext, operation: "Doppelte Habit-Abschlüsse bereinigen")
            }
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }
}
