import Foundation
import OSLog
import UserNotifications

@MainActor
enum HabitNotificationService {
    private static var schedulingGeneration = 0
    private static let logger = Logger(subsystem: "de.pasukistudio.elyra-vita", category: "HabitNotifications")

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func schedule(for habits: [Habit], completions: [HabitCompletion] = [], from startDate: Date = .now) async {
        schedulingGeneration += 1
        let generation = schedulingGeneration
        let center = UNUserNotificationCenter.current()
        let existingRequests = await center.pendingNotificationRequests()
        guard generation == schedulingGeneration else { return }
        let habitRequestIDs = existingRequests.map(\.identifier).filter { $0.hasPrefix("habit-") }
        center.removePendingNotificationRequests(withIdentifiers: habitRequestIDs)
        let nonHabitRequestCount = existingRequests.count - habitRequestIDs.count
        let calendar = Calendar.current
        var requests: [(date: Date, request: UNNotificationRequest)] = []

        for habit in habits where !habit.isArchived {
            let completionDays = completions.filter { $0.habitID == habit.id }.map(\.day)
            for offset in 0..<30 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: startDate)), habit.isDue(on: day, calendar: calendar, completionDays: completionDays), let fireDate = calendar.date(bySettingHour: habit.reminderHour, minute: habit.reminderMinute, second: 0, of: day), fireDate > Date() else { continue }
                let content = UNMutableNotificationContent()
                content.title = "Gewohnheit fällig"
                content.body = habit.name
                content.sound = .default
                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                requests.append((fireDate, UNNotificationRequest(identifier: "habit-\(habit.id.uuidString)-\(offset)", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))))
            }
        }

        let availableSlots = max(0, 64 - nonHabitRequestCount)
        for candidate in requests.sorted(by: { $0.date < $1.date }).prefix(availableSlots) {
            guard generation == schedulingGeneration else { return }
            do {
                try await center.add(candidate.request)
            } catch {
                logger.error("Notification konnte nicht geplant werden: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
