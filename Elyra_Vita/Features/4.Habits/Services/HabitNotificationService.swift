import Foundation
import OSLog
import UserNotifications

@MainActor
enum HabitNotificationService {
    struct ScheduleResult {
        let scheduledCount: Int
        let skippedCount: Int
        let failedCount: Int
    }

    private static var schedulingGeneration = 0
    private static let logger = Logger(
        subsystem: "de.pasukistudio.elyra-vita",
        category: "HabitNotifications"
    )

    static func synchronize(habits: [Habit], completions: [HabitCompletion]) async -> ScheduleResult {
        let activeHabits = habits.filter { !$0.isArchived }
        guard !activeHabits.isEmpty else {
            return await schedule(for: [], completions: completions)
        }
        guard await requestPermission() else {
            _ = await schedule(for: [], completions: completions)
            return ScheduleResult(scheduledCount: 0, skippedCount: 0, failedCount: 0)
        }
        return await schedule(for: activeHabits, completions: completions)
    }

    static func requestPermission() async -> Bool {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        return (try? await UNUserNotificationCenter.current().requestAuthorization(options: options)) ?? false
    }

    static func schedule(
        for habits: [Habit],
        completions: [HabitCompletion] = [],
        from startDate: Date = .now
    ) async -> ScheduleResult {
        schedulingGeneration += 1
        let generation = schedulingGeneration
        let center = UNUserNotificationCenter.current()
        let existingRequests = await center.pendingNotificationRequests()
        guard generation == schedulingGeneration else {
            return ScheduleResult(scheduledCount: 0, skippedCount: 0, failedCount: 0)
        }
        let nonHabitRequestCount = removeExistingHabitRequests(
            from: existingRequests,
            center: center
        )
        let calendar = Calendar.current
        let requests = requests(
            for: habits,
            completions: completions,
            startDate: startDate,
            calendar: calendar
        )
        let availableSlots = max(0, 64 - nonHabitRequestCount)
        let candidates = requests.sorted(by: { $0.date < $1.date })
        let failedCount = await add(
            candidates.prefix(availableSlots),
            to: center,
            generation: generation
        )
        guard generation == schedulingGeneration else {
            return ScheduleResult(scheduledCount: 0, skippedCount: 0, failedCount: failedCount)
        }
        return ScheduleResult(
            scheduledCount: max(0, min(candidates.count, availableSlots) - failedCount),
            skippedCount: max(0, candidates.count - availableSlots),
            failedCount: failedCount
        )
    }

    private static func removeExistingHabitRequests(
        from requests: [UNNotificationRequest],
        center: UNUserNotificationCenter
    ) -> Int {
        let habitRequestIDs = requests.map(\.identifier).filter { $0.hasPrefix("habit-") }
        center.removePendingNotificationRequests(withIdentifiers: habitRequestIDs)
        return requests.count - habitRequestIDs.count
    }

    private static func requests(
        for habits: [Habit],
        completions: [HabitCompletion],
        startDate: Date,
        calendar: Calendar
    ) -> [(date: Date, request: UNNotificationRequest)] {
        habits
            .filter { !$0.isArchived }
            .flatMap { habit in
                let completionDays = completions.filter { $0.habitID == habit.id }.map(\.day)
                return requests(
                    for: habit,
                    completionDays: completionDays,
                    startDate: startDate,
                    calendar: calendar
                )
            }
    }

    private static func requests(
        for habit: Habit,
        completionDays: [Date],
        startDate: Date,
        calendar: Calendar
    ) -> [(date: Date, request: UNNotificationRequest)] {
        let content = notificationContent(for: habit)
        switch habit.recurrence {
        case .daily:
            let components = DateComponents(hour: habit.reminderHour, minute: habit.reminderMinute)
            return [(.distantFuture, UNNotificationRequest(
                identifier: "habit-\(habit.id.uuidString)-daily",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            ))]
        case .selectedDays:
            return (1 ... 7)
                .filter { habit.selectedWeekdaysMask & (1 << ($0 - 1)) != 0 }
                .map { weekday in
                    let components = DateComponents(
                        hour: habit.reminderHour,
                        minute: habit.reminderMinute,
                        weekday: weekday
                    )
                    return (.distantFuture, UNNotificationRequest(
                        identifier: "habit-\(habit.id.uuidString)-weekday-\(weekday)",
                        content: content,
                        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                    ))
                }
        case .weekly, .monthly:
            return nextFlexibleRequest(
                for: habit,
                content: content,
                completionDays: completionDays,
                startDate: startDate,
                calendar: calendar
            ).map { [$0] } ?? []
        }
    }

    private static func nextFlexibleRequest(
        for habit: Habit,
        content: UNMutableNotificationContent,
        completionDays: [Date],
        startDate: Date,
        calendar: Calendar
    ) -> (date: Date, request: UNNotificationRequest)? {
        for offset in 0 ..< 370 {
            guard let day = calendar.date(
                byAdding: .day,
                value: offset,
                to: calendar.startOfDay(for: startDate)
            ),
                shouldSchedule(
                    habit: habit,
                    on: day,
                    from: startDate,
                    calendar: calendar,
                    completionDays: completionDays
                ),
                let fireDate = calendar.date(
                    bySettingHour: habit.reminderHour,
                    minute: habit.reminderMinute,
                    second: 0,
                    of: day
                ),
                fireDate > Date() else { continue }

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            return (fireDate, UNNotificationRequest(
                identifier: "habit-\(habit.id.uuidString)-next",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            ))
        }
        return nil
    }

    private static func add(
        _ candidates: ArraySlice<(date: Date, request: UNNotificationRequest)>,
        to center: UNUserNotificationCenter,
        generation: Int
    ) async -> Int {
        var failedCount = 0
        for candidate in candidates {
            guard generation == schedulingGeneration else { return failedCount }
            do {
                try await center.add(candidate.request)
            } catch {
                failedCount += 1
                logger.error(
                    "Notification konnte nicht geplant werden: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
        return failedCount
    }

    private static func notificationContent(for habit: Habit) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Gewohnheit fällig"
        content.body = habit.name
        content.sound = .default
        return content
    }

    /// Verteilt Wochen-/Monatsziele gleichmäßig über den Zeitraum, statt an
    /// jedem einzelnen Tag dieselbe Erinnerung zu senden.
    static func shouldSchedule(
        habit: Habit,
        on day: Date,
        from startDate: Date,
        calendar: Calendar,
        completionDays: [Date]
    ) -> Bool {
        guard habit.isDue(on: day, calendar: calendar, completionDays: completionDays) else { return false }
        guard habit.recurrence == .weekly || habit.recurrence == .monthly else { return true }

        let component: Calendar.Component = habit.recurrence == .weekly ? .weekOfYear : .month
        guard let interval = calendar.dateInterval(of: component, for: day),
              let periodEnd = calendar.date(byAdding: component, value: 1, to: interval.start),
              let dayCount = calendar.dateComponents([.day], from: interval.start, to: periodEnd).day,
              dayCount > 0 else { return false }

        let completed = Set(
            completionDays
                .filter { $0 >= interval.start && $0 < periodEnd }
                .map { calendar.startOfDay(for: $0) }
        ).count
        let remaining = max(0, habit.targetCount - completed)
        guard remaining > 0 else { return false }

        // Bereits vergangene Tage können nicht mehr benachrichtigt werden.
        // Die verfügbaren Tage beginnen deshalb beim Scheduling-Start oder am
        // Periodenanfang, je nachdem welcher Zeitpunkt später liegt.
        let firstDay = max(calendar.startOfDay(for: startDate), interval.start)
        let firstIndex = calendar.dateComponents([.day], from: interval.start, to: firstDay).day ?? 0
        let dayIndex = calendar.dateComponents([.day], from: interval.start, to: calendar.startOfDay(for: day)).day ?? 0
        let availableDayCount = max(0, dayCount - firstIndex)
        guard availableDayCount > 0 else { return false }

        let scheduledIndices = (0 ..< min(remaining, availableDayCount)).map { index in
            firstIndex + ((index + 1) * availableDayCount) / (min(remaining, availableDayCount) + 1)
        }
        return scheduledIndices.contains(dayIndex)
    }
}
